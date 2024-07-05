package Geo::Coder::Free::Display;

# Display a page. Certain variables are available to all templates, such as
# the stuff in the configuration file

=head1 VERSION

Version 0.36

=cut

our $VERSION = '0.36';

use strict;
use warnings;
use Config::Auto;
use CGI::Info;
use Data::Dumper;
use File::Spec;
use Template::Filters;
use Template::Plugin::EnvHash;
use HTML::SocialMedia;
use Geo::Coder::Free::Utils;
use Error;
use Fatal qw(:void open);
use File::pfopen;

my %blacklist = (
	'MD' => 1,
	'RU' => 1,
	'CN' => 1,
	'BR' => 1,
	'UY' => 1,
	'TR' => 1,
	'MA' => 1,
	'VE' => 1,
	'SA' => 1,
	'CY' => 1,
	'CO' => 1,
	'MX' => 1,
	'IN' => 1,
	'RS' => 1,
	'PK' => 1,
);

our $sm;
our $smcache;

sub new {
	my $proto = shift;
	my %args = (ref($_[0]) eq 'HASH') ? %{$_[0]} : @_;

	my $class = ref($proto) || $proto;

	if(defined($ENV{'HTTP_REFERER'})) {
		# Protect against Shellshocker
		require Data::Validate::URI;
		Data::Validate::URI->import();

		unless(Data::Validate::URI->new()->is_uri($ENV{'HTTP_REFERER'})) {
			return 0;
		}
	}

	my $info = $args{info} || CGI::Info->new();

	unless($info->is_search_engine() || !defined($ENV{'REMOTE_ADDR'})) {
		require CGI::IDS;
		CGI::IDS->import();

		my $ids = CGI::IDS->new();
		$ids->set_scan_keys(scan_keys => 1);
		my $impact = $ids->detect_attacks(request => $info->params());
		if($impact > 0) {
			die "IDS impact is $impact";
		}

		require Data::Throttler;
		Data::Throttler->import();

		# Handle YAML Errors
		my $db_file = $info->tmpdir() . '/throttle';
		eval {
			my $throttler = Data::Throttler->new(
				max_items => 30,
				interval => 90,
				backend => 'YAML',
				backend_options => {
					db_file => $db_file
				}
			);

			unless($throttler->try_push(key => $ENV{'REMOTE_ADDR'})) {
				die "$ENV{REMOTE_ADDR} connexion throttled";
			}
		};
		if($@) {
			unlink($db_file);
		}
		if(my $lingua = $args{lingua}) {
			if($blacklist{uc($lingua->country())}) {
				die "$ENV{REMOTE_ADDR} is from a blacklisted country ", $lingua->country();
			}
		}
	}
	my $config_dir;
	if($ENV{'CONFIG_DIR'}) {
		$config_dir = $ENV{'CONFIG_DIR'};
	} else {
		$config_dir = File::Spec->catdir(
				$info->script_dir(),
				File::Spec->updir(),
				File::Spec->updir(),
				'conf'
			);

		if(!-d $config_dir) {
			$config_dir = File::Spec->catdir(
					$info->script_dir(),
					File::Spec->updir(),
					'conf'
				);
		}

		if(!-d $config_dir) {
			if($ENV{'DOCUMENT_ROOT'}) {
				$config_dir = File::Spec->catdir(
					$ENV{'DOCUMENT_ROOT'},
					File::Spec->updir(),
					'lib',
					'conf'
				);
			} else {
				$config_dir = File::Spec->catdir(
					$ENV{'HOME'},
					'lib',
					'conf'
				);
			}
		}

		if(!-d $config_dir) {
			if($args{config_directory}) {
				$config_dir = $args{config_directory};
			} elsif($args{logger}) {
				while(my ($k, $v) = each %ENV) {
					$args{logger}->debug("$k=$v");
				}
			}
		}
	}
	if($args{'logger'}) {
		$args{'logger'}->debug(__PACKAGE__, ': ', __LINE__, " path = $config_dir");
	}
	my $config;
	eval {
		if(-r File::Spec->catdir($config_dir, $info->domain_name())) {
			$config = Config::Auto::parse($info->domain_name(), path => $config_dir);
		} elsif (-r File::Spec->catdir($config_dir, 'default')) {
			$config = Config::Auto::parse('default', path => $config_dir);
		} else {
			die 'no suitable config file found';
		}
	};
	if($@ || !defined($config)) {
		die "Configuration error: $@: $config_dir/", $info->domain_name();
	}

	# The values in config are defaults which can be overridden by
	# the values in args{config}
	if(defined($args{'config'})) {
		$config = { %{$config}, %{$args{'config'}} };
	}

	Template::Filters->use_html_entities();

	my $self = {
		_config => $config,
		_info => $info,
		_logger => $args{logger},
		_cachedir => $args{cachedir},
		%args,
	};

	if(my $lingua = $args{'lingua'}) {
		$self->{'_lingua'} = $lingua;
	}
	if(my $key = $info->param('key')) {
		$self->{'_key'} = $key;
	}
	if(my $page = $info->param('page')) {
		$self->{'_page'} = $page;
	}

	if(my $twitter = $config->{'twitter'}) {
		$smcache ||= ::create_memory_cache(config => $config, logger => $args{'logger'}, namespace => 'HTML::SocialMedia');
		$sm ||= HTML::SocialMedia->new({ twitter => $twitter, cache => $smcache, lingua => $args{lingua}, logger => $args{logger} });
		$self->{'_social_media'}->{'twitter_tweet_button'} = $sm->as_string(twitter_tweet_button => 1);
	} elsif(!defined($sm)) {
		$smcache = ::create_memory_cache(config => $config, logger => $args{'logger'}, namespace => 'HTML::SocialMedia');
		$sm = HTML::SocialMedia->new({ cache => $smcache, lingua => $args{lingua}, logger => $args{logger} });
	}
	$self->{'_social_media'}->{'facebook_share_button'} = $sm->as_string(facebook_share_button => 1);
	# $self->{'_social_media'}->{'google_plusone'} = $sm->as_string(google_plusone => 1);

	return bless $self, $class;
}

# Call this to display the page
# It calls http() to create the HTTP headers, then html() to create the body
sub as_string {
	my ($self, $args) = @_;

	# TODO: Get all cookies and send them to the template.
	# 'cart' is an example
	unless($args && $args->{cart}) {
		my $purchases = $self->{_info}->get_cookie(cookie_name => 'cart');
		if($purchases) {
			my %cart = split(/:/, $purchases);
			$args->{cart} = \%cart;
		}
	}
	unless($args && $args->{itemsincart}) {
		if($args->{cart}) {
			my $itemsincart;
			foreach my $key(keys %{$args->{cart}}) {
				if(defined($args->{cart}{$key}) && ($args->{cart}{$key} ne '')) {
					$itemsincart += $args->{cart}{$key};
				} else {
					delete $args->{cart}{$key};
				}
			}
			$args->{itemsincart} = $itemsincart;
		}
	}

	# my $html = $self->html($args);
	# unless($html) {
		# return;
	# }
	# return $self->http() . $html;
	my $rc = $self->http();
	if($rc =~ /^Location:\s/ms) {
		return $rc;
	}
	return $rc . $self->html($args);
}

sub get_template_path {
	my $self = shift;
	my %args = (ref($_[0]) eq 'HASH') ? %{$_[0]} : @_;

	if($self->{_logger}) {
		$self->{_logger}->trace('Entering get_template_path');
	}

	if($self->{_filename}) {
		return $self->{_filename};
	}

	my $dir = $self->{_config}->{root_dir} || $self->{_info}->root_dir();
	if($self->{_logger}) {
		$self->{_logger}->debug(__PACKAGE__, ': ', __LINE__, ": root_dir $dir");
		$self->{_logger}->debug(Data::Dumper->new([$self->{_config}])->Dump());
	}
	$dir .= '/templates';

	# Look in .../robot or .../mobile first, if appropriate
	my $prefix = '';

	# Look in .../en/gb/web, then .../en/web then /web
	if($self->{_lingua}) {
		my $lingua = $self->{_lingua};

		$self->_debug({ message => 'Requested language: ' . $lingua->requested_language() });

		# FIXME: look for lower priority languages if the highest isn't found
		my $candidate;
		if($lingua->sublanguage_code_alpha2()) {
			$candidate = "$dir/" . $lingua->code_alpha2() . '/' . $lingua->sublanguage_code_alpha2();
			$self->_debug({ message => "check for directory $candidate" });
			if(!-d $candidate) {
				$candidate = undef;
			}
		}
		if((!defined($candidate)) && defined($lingua->code_alpha2())) {
			$candidate = "$dir/" . $lingua->code_alpha2();
			$self->_debug({ message => "check for directory $candidate" });
			if(!-d $candidate) {
				$candidate = undef;
			}
		}
		if($candidate) {
			$prefix = $self->_append_browser_type({ directory => $candidate });
		}
	}

	$prefix .= $self->_append_browser_type({ directory => "$dir/default" });
	$prefix .= $self->_append_browser_type({ directory => $dir });

	# Fall back to .../web, or if that fails, assume no web, robot or
	# mobile variant
	$prefix .= "$dir/web:$dir/default/web:$dir/default:$dir";

	$self->_debug({ message => "prefix: $prefix" });

	my $modulepath = $args{'modulepath'} || ref($self);
	$modulepath =~ s/::/\//g;

	if($prefix =~ /\.\.\//) {
		throw Error::Simple("Prefix must not contain ../ ($prefix)");
	}

	# Untaint the prefix value which may have been read in from a configuration file
	($prefix) = ($prefix =~ m/^([A-Z0-9_\.\-\/:]+)$/ig);

	my ($fh, $filename) = File::pfopen::pfopen($prefix, $modulepath, 'tmpl:tt:html:htm:txt');
	if((!defined($filename)) || (!defined($fh))) {
		throw Error::Simple("Can't find suitable $modulepath html or tmpl file in $prefix in $dir or a subdir");
	}
	close($fh);
	$self->_debug({ message => "using $filename" });
	$self->{_filename} = $filename;
	return $filename;
}

sub set_cookie
{
	my $self = shift;
	my %params = (ref($_[0]) eq 'HASH') ? %{$_[0]} : @_;

	foreach my $key(keys(%params)) {
		$self->{_cookies}->{$key} = $params{$key};
	}
	return $self;
}

sub http {
	my $self = shift;

	# TODO: Only session cookies as the moment
	my $cookies = $self->{_cookies};
	if(defined($cookies)) {
		foreach my $cookie (keys(%{$cookies})) {
			if(exists($cookies->{$cookie})) {
				print "Set-Cookie:$cookie=$cookies->{$cookie}; path=/; HttpOnly\n";
			} else {
				print "Set-Cookie:$cookie=0:0; path=/; HttpOnly\n";
			}
		}
	}

	my $language;
	if($self->{_lingua}) {
		$language = $self->{_lingua}->language();
	} else {
		$language = 'English';
	}

	my $rc;

	my $filename = $self->get_template_path();
	if($filename =~ /\.txt$/) {
		$rc = "Content-Type: text/plain\n";
	} elsif($language eq 'Japanese') {
		binmode(STDOUT, ':utf8');

		$rc = "Content-Type: text/html; charset=UTF-8\n";
	} elsif($language eq 'Polish') {
		binmode(STDOUT, ':utf8');

		# print "Content-Type: text/html; charset=ISO-8859-2\n";
		$rc = "Content-Type: text/html; charset=UTF-8\n";
	} else {
		# $rc = "Content-Type: text/html; charset=ISO-8859-1\n";
		$rc = "Content-Type: text/html; charset=UTF-8\n";
	}

	# https://www.owasp.org/index.php/Clickjacking_Defense_Cheat_Sheet
	# https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/X-Content-Type-Options
	return $rc . "X-Frame-Options: SAMEORIGIN\nX-Content-Type-Options: nosniff\nReferrer-Policy: strict-origin-when-cross-origin\n\n";
}

# Override this routine in a subclass if you wish to create special arguments to
# send to the template
sub html {
	my $self = shift;
	my %params = (ref($_[0]) eq 'HASH') ? %{$_[0]} : @_;

	my $filename = $self->get_template_path();
	my $rc;
	if($filename =~ /.+\.t(mpl|t)$/) {
		require Template;
		Template->import();

		my $info = $self->{_info};

		# The values in config are defaults which can be overridden by
		# the values in info, then the values in params
		my $vals;
		if(defined($self->{_config})) {
			if($info->params()) {
				$vals = { %{$self->{_config}}, %{$info->params()} };
			} else {
				$vals = $self->{_config};
			}
			if(scalar(keys %params)) {
				$vals = { %{$vals}, %params };
			}
		} elsif(scalar(keys %params)) {
			$vals = { %{$info->params()}, %params };
		} else {
			$vals = $info->params();
		}
		$vals->{script_name} = $info->script_name();

		$vals->{cart} = $info->get_cookie(cookie_name => 'cart');
		$vals->{lingua} = $self->{_lingua};
		$vals->{social_media} = $self->{_social_media};
		$vals->{info} = $info;
		$vals->{as_string} = $info->as_string();

		my $template = Template->new({
			INTERPOLATE => 1,
			POST_CHOMP => 1,
			ABSOLUTE => 1,
		});

		if(!$template->process($filename, $vals, \$rc)) {
			if(my $err = $template->error()) {
				throw Error::Simple($err);
			}
			throw Error::Simple("Unknown error in template: $filename");
		}
	} elsif($filename =~ /\.(html?|txt)$/) {
		open(my $fin, '<', $filename) || throw Error::Simple("$filename: $!");

		my @lines = <$fin>;

		close $fin;

		$rc = join('', @lines);
	} else {
		throw Error::Simple("Unhandled file type $filename");
	}

	if(($filename !~ /.txt$/) && ($rc =~ /\smailto:(.+?)>/) && ($1 !~ /^&/)) {
		$self->_debug({ message => "Found mailto link $1, you should remove it or use " . obfuscate($1) . ' instead' });
	}

	return $rc;
}

sub _debug
{
	my $self = shift;

	if($self->{_logger}) {
		my %params = (ref($_[0]) eq 'HASH') ? %{$_[0]} : @_;
		if($ENV{'REMOTE_ADDR'}) {
			$self->{_logger}->debug("$ENV{'REMOTE_ADDR'}: $params{'message'}");
		} else {
			$self->{_logger}->debug($params{'message'});
		}
	}
	return $self;
}

sub obfuscate {
	return map { '&#' . ord($_) . ';' } split(//, shift);
}

sub _append_browser_type {
	my $self = shift;
	my %args = (ref($_[0]) eq 'HASH') ? %{$_[0]} : @_;

	if($self->{_logger}) {
		$self->{_logger}->trace('_append_browser_type');
	}

	my $directory = $args{'directory'};

	return unless(defined($directory));

	if($self->{_logger}) {
		$self->{_logger}->debug("_append_browser_type: directory = $directory");
	}

	my $rc;
	if(-d $directory) {
		if($self->{_info}->is_search_engine()) {
			$rc = "$directory/search:$directory/robot:";
		} elsif($self->{_info}->is_mobile()) {
			$rc = "$directory/mobile:";
		} elsif($self->{_info}->is_robot()) {
			$rc = "$directory/robot:$directory/search:";
		}
		$rc .= "$directory/web:";

		$self->_debug({ message => "_append_directory_type: $directory=>$rc" });
		return $rc;
	}

	return '';	# Don't return undef or else the caller may use an uninit variable
}

1;
