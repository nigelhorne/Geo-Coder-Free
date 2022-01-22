package Geo::Coder::Free::Config;

# VWF is licensed under GPL2.0 for personal use only
# njh@bandsman.co.uk

# Site independent configuration file
# Takes three optional arguments:
#	info (CGI::Info object)
#	logger
#	default_config_directory - used when the configuration directory can't be worked out
#	config (ref to hash to of values to override in the config file
# Values in the file are overridden by what's in the environment

use warnings;
use strict;
use Config::Auto;
use CGI::Info;
use File::Spec;

sub new {
	my $proto = shift;
	my %args = (ref($_[0]) eq 'HASH') ? %{$_[0]} : @_;

	my $class = ref($proto) || $proto;

	my $info = $args{info} || CGI::Info->new();

	my $path;
	if($ENV{'CONFIG_DIRECTORY'}) {
		$path = $ENV{'CONFIG_DIRECTORY'};
	} else {
		$path = File::Spec->catdir(
				$info->script_dir(),
				File::Spec->updir(),
				File::Spec->updir(),
				'conf'
			);
		if($args{logger}) {
			$args{logger}->debug("Looking for configuration $path/", $info->domain_name());
		}

		if(!-d $path) {
			$path = File::Spec->catdir(
					$info->script_dir(),
					File::Spec->updir(),
					'conf'
				);
			if($args{logger}) {
				$args{logger}->debug("Looking for configuration $path/", $info->domain_name());
			}
		}

		if(!-d $path) {
			if($ENV{'DOCUMENT_ROOT'}) {
				$path = File::Spec->catdir(
					$ENV{'DOCUMENT_ROOT'},
					File::Spec->updir(),
					'lib',
					'conf'
				);
			} else {
				$path = File::Spec->catdir(
					$ENV{'HOME'},
					'lib',
					'conf'
				);
			}
			if($args{logger}) {
				$args{logger}->debug("Looking for configuration $path/", $info->domain_name());
			}
		}

		if(!-d $path) {
			if($args{default_config_directory}) {
				$path = $args{default_config_directory};
			} elsif($args{logger}) {
				while(my ($key,$value) = each %ENV) {
					$args{logger}->debug("$key=$value");
				}
			}
		}

		if(my $lingua = $args{'lingua'}) {
			my $language;
			if(($language = $lingua->language_code_alpha2()) && (-d "$path/$language")) {
				$path .= "/$language";
			} elsif(-d "$path/default") {
				$path .= '/default';
			}
		}
	}
	# if($args{'debug'}) {
		# # Not sure this really does anything
		# $Config::Auto::Debug = 1;
	# }
	my $config;
	my $config_file;
	eval {
		$config_file = File::Spec->catdir($path, $info->domain_name());
		if($args{logger}) {
			$args{logger}->debug("Configuration path: $config_file");
		}
		if(-r $config_file) {
			if($args{logger}) {
				$args{logger}->debug("Found configuration in $config_file");
			}
			$config = Config::Auto::parse($config_file);
		} elsif (-r File::Spec->catdir($path, 'default')) {
			$config_file = File::Spec->catdir($path, 'default');
			if($args{logger}) {
				$args{logger}->debug("Found configuration in $config_file");
			}
			$config = Config::Auto::parse('default', path => $path);
		} else {
			die "no suitable config file found in $path";
		}
	};
	if($@ || !defined($config)) {
		throw Error::Simple("$config_file: configuration error: $@");
	}

	# The values in config are defaults which can be overridden by
	# the values in args{config}
	if(defined($args{'config'})) {
		$config = { %{$config}, %{$args{'config'}} };
	}

	# Allow variables to be overridden by the environment
	foreach my $key(keys %{$config}) {
		if($ENV{$key}) {
			$config->{$key} = $ENV{$key};
		}
	}

	# Config::Any turns fields with spaces into arrays, put them back
	foreach my $field('Contents', 'SiteTitle') {
		my $value = $config->{$field};

		if(ref($value) eq 'ARRAY') {
			$config->{$field} = join(' ', @{$value});
		}
	}

	unless($config->{'config_path'}) {
		$config->{'config_path'} = File::Spec->catdir($path, $info->domain_name());
	}

	return bless $config, $class;
}

sub AUTOLOAD {
	our $AUTOLOAD;
	my $key = $AUTOLOAD;

	$key =~ s{.*::}{};

	my $self = shift or return undef;
	return $self->{$key};
}

1;
