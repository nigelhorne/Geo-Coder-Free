package Geo::Coder::Free::Display::index;

use strict;
use warnings;

# Display the index page

use Geo::Coder::Free::Display;
use String::Random;

our @ISA = ('Geo::Coder::Free::Display');

sub html {
	my $self = shift;
	my %args = (ref($_[0]) eq 'HASH') ? %{$_[0]} : @_;

	my $info = $self->{_info};
	my $allowed = {
		'person' => undef,
		'action' => 'login',
		'name' => undef,
		'password' => undef,
	};
	my $params = $info->params({ allowed => $allowed });
	my $config = $args{'config'};
	my $logger = $args{'logger'};

	if(!defined($params)) {
		# Display the main index page
		return $self->SUPER::html();
	}

	my $cache;
	if(defined($params->{'action'})) {
		$self->{'logindata'} ||= create_disc_cache(config => $config, logger => $logger, namespace => 'logindata', root_dir => $args{'cachedir'});
		$cache = $self->{'logindata'};
		if($params->{'action'} eq 'login') {
			if((!defined($params->{'name'})) || !defined($params->{'password'})) {
				return $self->SUPER::html({ error => 'Fill in name and password' });
			}
			# FIXME - read from configuration file
			if(($params->{'name'} ne 'Geo::Coder::Free') || ($params->{'name'} ne 'Password')) {
				return $self->SUPER::html({ error => 'Incorrect name or password' });
			}
			my $rand = String::Random->new();
			my $key;
			do {
				$key = $rand->randregex('\w\w\w\w\w\w\w\w');
			} while($cache->get($key));     # FIXME: race condition
			$self->set_cookie('session' => $key);
			$self->{'logindata'}->set('Geo::Coder::Free', $key, '1 day');
			my $script_name = $info->script_name();
			return "Location: $script_name?page=admin";
		}
	}
	if(my $cookie = $info->get_cookie(cookie_name => 'session')) {
		if(my $key = $self->{'logindata'}->get('Geo::Coder::Free')) {
			if($cookie eq $key) {
				my $script_name = $info->script_name();
				return "Location: $script_name?page=admin";
			}
			$cache->delete($key);
		}
		return $self->SUPER::html({ error => 'You need to login to access the admin screen' });
	}

	if(!defined($info->person())) {
		return $self->SUPER::html({ error => 'Who do you want to contact?' });
	}

	my $index = $args{'index'};	# Handle into the database

	# Look in the index.db for the name given as the CGI argument and
	# find their e-mail address
	my $to = ($index->email({ entry => $info->person() }))[0];

	# Insert code here to error if $to isn't defined
	if(!defined($to)) {
		die 'No email entry assigned to ' . $info->person();
	}

	if(open(my $fout, '|-', '/usr/sbin/sendmail -t')) {
		print $fout "To: $to\n",
			"From: webmaster\n",
			"Subject: Geo::Coder::Free sending an e-mail\n\n",
			"Hello, world\n";

		close $fout;

		if($self->{_logger}) {
			$self->{_logger}->trace("E-mail sent to $to");
		}

		return $self->SUPER::html({ action => 'sent', updated => $index->updated() });
	}
	return $self->SUPER::html({ error => "Can't find /usr/sbin/sendmail", updated => $index->updated() });
}

1;
