#!/usr/bin/env perl

# Geo::Coder::Free is licensed under GPL2.0 for personal use only
# njh@bandsman.co.uk

# Based on VWF - https://github.com/nigelhorne/vwf

# Can be tested at the command line, e.g.:
#	root_dir=$(pwd)/.. ./page.fcgi page=index
# To mimic a French mobile site:
#	root_dir=$(pwd)/.. ./page.fcgi mobile=1 page=index lang=fr
# To turn off linting of HTML on a search-engine landing page
#	root_dir=$(pwd)/.. ./page.fcgi --search-engine page=index lint_content=0

# TODO: use the memory_cache in the config file for the database searches

use strict;
use warnings;
# use diagnostics;

no lib '.';

use Log::Log4perl qw(:levels);	# Put first to cleanup last
use CGI::Carp qw(fatalsToBrowser);
use CGI::Info;
use CGI::Lingua;
use Database::Abstraction;
use File::Basename;
# use CGI::Alert $ENV{'SERVER_ADMIN'} || 'you@example.com';
use FCGI;
use FCGI::Buffer;
use Log::Any::Adapter;
use Error qw(:try);
use File::Spec;
use Log::WarnDie 0.09;
use CGI::ACL;
use HTTP::Date;
# FIXME: Gives Insecure dependency in require while running with -T switch in Module/Runtime.pm
# use Taint::Runtime qw($TAINT taint_env);
use POSIX qw(strftime);
use autodie qw(:all);

# use lib '/usr/lib';	# This needs to point to the Geo::Coder::Free directory lives,
			# i.e. the contents of the lib directory in the
			# distribution
use lib '../lib';

use Geo::Coder::Free;
use Geo::Coder::Free::Config;

# $TAINT = 1;
# taint_env();

my $info = CGI::Info->new();
my @suffixlist = ('.pl', '.fcgi');
my $script_name = basename($info->script_name(), @suffixlist);
my $tmpdir = $info->tmpdir();

if($ENV{'HTTP_USER_AGENT'}) {
	# open STDERR, ">&STDOUT";
	close STDERR;
	open(STDERR, '>>', File::Spec->catfile($tmpdir, "$script_name.stderr"));
}

Log::WarnDie->filter(\&filter);

my $vwflog;	# Location of the vwf.log file, read in from the config file - default = logdir/vwf.log

my $infocache;
my $linguacache;
my $buffercache;
my $geocoder;

my $script_dir = $info->script_dir();
Log::Log4perl::init("$script_dir/../conf/$script_name.l4pconf");
my $logger = Log::Log4perl->get_logger($script_name);
Log::WarnDie->dispatcher($logger);

# my $pagename = "Geo::Coder::Free::Display::$script_name";
# eval "require $pagename";
use Geo::Coder::Free::Display::index;
use Geo::Coder::Free::Display::query;

# use Geo::Coder::Free::DB::Maxmind;
use Geo::Coder::Free::DB::openaddresses;

my $config = Geo::Coder::Free::Config->new({ logger => $logger, info => $info });
die 'Set OPENADDR_HOME' if(!$config->OPENADDR_HOME());

my $database_dir = "$script_dir/../lib/Geo/Coder/Free/MaxMind/databases";
Database::Abstraction::init({ directory => $database_dir, logger => $logger });

my $openaddresses = Geo::Coder::Free::DB::openaddresses->new(openaddr => $config->OPENADDR_HOME());
if($@) {
	$logger->error($@);
	Log::WarnDie->dispatcher(undef);
	die $@;
}

# http://www.fastcgi.com/docs/faq.html#PerlSignals
my $requestcount = 0;
my $handling_request = 0;
my $exit_requested = 0;

# CHI->stats->enable();

my $acl = CGI::ACL->new()->deny_country(country => ['RU', 'CN'])->allow_ip('131.161.0.0/16')->allow_ip('127.0.0.1');

sub sig_handler {
	$exit_requested = 1;
	$logger->trace('In sig_handler');
	if(!$handling_request) {
		$logger->info('Shutting down');
		if($buffercache) {
			$buffercache->purge();
		}
		CHI->stats->flush();
		Log::WarnDie->dispatcher(undef);
		exit(0);
	}
}

$SIG{USR1} = \&sig_handler;
$SIG{TERM} = \&sig_handler;
$SIG{PIPE} = 'IGNORE';
$ENV{'PATH'} = '/usr/local/bin:/bin:/usr/bin';	# For insecurity

$SIG{__WARN__} = sub {
	if(open(my $fout, '>>', File::Spec->catfile($tmpdir, "$script_name.stderr"))) {
		print $fout @_;
	}
	Log::WarnDie->dispatcher(undef);
	CORE::die @_
};

my $request = FCGI::Request();

# It would be really good to send 429 to search engines when there are more than, say, 5 requests being handled.
# But I don't think that's possible with the FCGI module

while($handling_request = ($request->Accept() >= 0)) {
	unless($ENV{'REMOTE_ADDR'}) {
		# debugging from the command line
		$ENV{'NO_CACHE'} = 1;
		if((!defined($ENV{'HTTP_ACCEPT_LANGUAGE'})) && defined($ENV{'LANG'})) {
			my $lang = $ENV{'LANG'};
			$lang =~ s/\..*$//;
			$lang =~ tr/_/-/;
			$ENV{'HTTP_ACCEPT_LANGUAGE'} = lc($lang);
		}
		Log::Any::Adapter->set('Stdout', log_level => 'trace');
		$logger = Log::Any->get_logger(category => $script_name);
		Log::WarnDie->dispatcher($logger);
		$openaddresses->set_logger($logger);
		$info->set_logger($logger);
		$Error::Debug = 1;
		# CHI->stats->enable();
		try {
			doit(debug => 1);
		} catch Error with {
			my $msg = shift;
			warn "$msg\n", $msg->stacktrace();
			$logger->error($msg);
		};
		last;
	}

	$requestcount++;
	Log::Any::Adapter->set( { category => $script_name }, 'Log4perl');
	$logger = Log::Any->get_logger(category => $script_name);
	$logger->info("Request $requestcount: ", $ENV{'REMOTE_ADDR'});
	$openaddresses->set_logger($logger);
	$info->set_logger($logger);

	my $start = [Time::HiRes::gettimeofday()];

	try {
		doit(debug => 0);
		my $timetaken = Time::HiRes::tv_interval($start);

		$logger->info("$script_name completed in $timetaken seconds");
	} catch Error with {
		my $msg = shift;
		$logger->error("$msg: ", $msg->stacktrace());
		if($buffercache) {
			$buffercache->clear();
			$buffercache = undef;
		}
	};

	$request->Finish();
	$handling_request = 0;
	if($exit_requested) {
		last;
	}
	if($ENV{SCRIPT_FILENAME}) {
		if(-M $ENV{SCRIPT_FILENAME} < 0) {
			last;
		}
	}
}

$logger->info("Shutting down");
if($buffercache) {
	$buffercache->purge();
}
CHI->stats->flush();
Log::WarnDie->dispatcher(undef);
exit(0);

sub doit
{
	CGI::Info->reset();

	$logger->debug('In doit - domain is ', $info->domain_name());

	my %params = (ref($_[0]) eq 'HASH') ? %{$_[0]} : @_;
	$infocache ||= create_memory_cache(config => $config, logger => $logger, namespace => 'CGI::Info');

	my $options = {
		cache => $infocache,
		logger => $logger
	};

	my $syslog;
	if($syslog = $config->syslog()) {
		if($syslog->{'server'}) {
			$syslog->{'host'} = delete $syslog->{'server'};
		}
		$options->{'syslog'} = $syslog;
	}
	$info = CGI::Info->new($options);

	if(!defined($info->param('page'))) {
		$logger->info('No page given in ', $info->as_string());
		choose();
		return;
	}

	$linguacache ||= create_memory_cache(config => $config, logger => $logger, namespace => 'CGI::Lingua');
	my $lingua = CGI::Lingua->new({
		supported => [ 'en-gb' ],
		cache => $linguacache,
		info => $info,
		logger => $logger,
		debug => $params{'debug'},
		syslog => $syslog,
	});

	$vwflog ||= ($config->vwflog() || File::Spec->catfile($info->logdir(), 'vwf.log'));
	if($vwflog && open(my $fout, '>>', $vwflog)) {
		print $fout
			'"', $info->domain_name(), '",',
			'"', strftime('%F %T', localtime), '",',
			'"', ($ENV{REMOTE_ADDR} ? $ENV{REMOTE_ADDR} : ''), '",',
			'"', $lingua->country(), '",',
			'"', $info->browser_type(), '",',
			'"', $lingua->language(), '",',
			'"', $info->as_string(), "\"\n";
		close($fout);
	}

	if($ENV{'REMOTE_ADDR'} && $acl->all_denied(lingua => $lingua)) {
		print "Status: 403 Forbidden\n",
			"Content-type: text/plain\n",
			"Pragma: no-cache\n\n";

		unless($ENV{'REQUEST_METHOD'} && ($ENV{'REQUEST_METHOD'} eq 'HEAD')) {
			print "Access Denied\n";
		}
		$logger->info($ENV{'REMOTE_ADDR'}, ': access denied');
		return;
	}

	my $args = {
		info => $info,
		optimise_content => 1,
		logger => $logger,
		lint_content => $info->param('lint_content') // $params{'debug'},
		lingua => $lingua
	};

	if(!$info->is_search_engine() && $config->root_dir() && ((!defined($info->param('action'))) || ($info->param('action') ne 'send'))) {
		$args->{'save_to'} = {
			directory => File::Spec->catfile($config->root_dir(), 'save_to'),
			ttl => 3600 * 24,
			create_table => 1
		};
	}

	my $fb = FCGI::Buffer->new()->init($args);

	my $cachedir = $params{'cachedir'} || $config->{disc_cache}->{root_dir} || File::Spec->catfile($tmpdir, 'cache');

	if($fb->can_cache()) {
		$buffercache ||= create_disc_cache(config => $config, logger => $logger, namespace => $script_name, root_dir => $cachedir);
		$fb->init(
			cache => $buffercache,
			# generate_304 => 0,
			cache_duration => '1 day',
		);
		if($fb->is_cached()) {
			return;
		}
	}

	$geocoder ||= Geo::Coder::Free->new(
		openaddr => $config->OPENADDR_HOME(),
		cache => create_memory_cache(config => $config, logger => $logger, namespace => $script_name, root_dir => $cachedir)
	);

	my $display;
	my $invalidpage;
	$args = {
		cachedir => $cachedir,
		info => $info,
		logger => $logger,
		lingua => $lingua,
		config => $config,
	};

	eval {
		my $page = $info->param('page');
		$page =~ s/#.*$//;
		# $display = Geo::Coder::Free::Display::$page->new($args);

		if($page eq 'index') {
			$display = Geo::Coder::Free::Display::index->new($args);
		} elsif($page eq 'query') {
			$display = Geo::Coder::Free::Display::query->new($args);
		} else {
			$logger->info("Unknown page $page");
			$invalidpage = 1;
		}
	};

	my $error = $@;
	if($error) {
		$logger->error($error);
		$display = undef;
	}

	if(defined($display)) {
		# Pass in handles to the databases
		print $display->as_string({
			geocoder => $geocoder,
			cachedir => $cachedir
		});
	} elsif($invalidpage) {
		choose();
		return;
	} else {
		$logger->debug('disabling cache');
		$fb->init(
			cache => undef,
		);
		if($error eq 'Unknown page to display') {
			print "Status: 400 Bad Request\n",
				"Content-type: text/plain\n",
				"Pragma: no-cache\n\n";

			unless($ENV{'REQUEST_METHOD'} && ($ENV{'REQUEST_METHOD'} eq 'HEAD')) {
				print "I don't know what you want me to display.\n";
			}
		} elsif($error =~ /Can\'t locate .* in \@INC/) {
			$logger->error($error);
			print "Status: 500 Internal Server Error\n",
				"Content-type: text/plain\n",
				"Pragma: no-cache\n\n";

			unless($ENV{'REQUEST_METHOD'} && ($ENV{'REQUEST_METHOD'} eq 'HEAD')) {
				print "Software error - contact the webmaster\n",
					"$error\n";
			}
		} else {
			# No permission to show this page
			print "Status: 403 Forbidden\n",
				"Content-type: text/plain\n",
				"Pragma: no-cache\n\n";

			unless($ENV{'REQUEST_METHOD'} && ($ENV{'REQUEST_METHOD'} eq 'HEAD')) {
				print "Access Denied\n";
			}
		}
		throw Error::Simple($error ? $error : $info->as_string());
	}
}

sub choose
{
	$logger->info('Called with no page to display');

	my $status = $info->status();

	if($status != 200) {
		require HTTP::Status;
		HTTP::Status->import();

		print "Status: $status ",
			HTTP::Status::status_message($status),
			"\n\n";
		return;
	}

	print "Status: 300 Multiple Choices\n",
		"Content-type: text/plain\n";

	my $path = $info->script_path();
	if(defined($path)) {
		my @statb = stat($path);
		my $mtime = $statb[9];
		print "Last-Modified: ", HTTP::Date::time2str($mtime), "\n";
	}

	print "\n";

	unless($ENV{'REQUEST_METHOD'} && ($ENV{'REQUEST_METHOD'} eq 'HEAD')) {
		print "/cgi-bin/page.fcgi?page=index\n",
			"/cgi-bin/page.fcgi?page=query\n";
	}
}

# False positives we don't need in the logs
sub filter {
	return 0 if($_[0] =~ /Can't locate Net\/OAuth\/V1_0A\/ProtectedResourceRequest.pm in /);
	return 0 if($_[0] =~ /Can't locate auto\/NetAddr\/IP\/InetBase\/AF_INET6.al in /);
	return 0 if($_[0] =~ /S_IFFIFO is not a valid Fcntl macro at /);

	return 1;
}
