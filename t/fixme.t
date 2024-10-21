#!perl -w

# Ensure that there are no FIXMEs in the code

use strict;
use warnings;

use Test::DescribeMe qw(author);
use Test::Most;

my @messages;

is($INC{'Devel/FIXME.pm'}, undef, "Devel::FIXME isn't loaded yet");

eval 'use Devel::FIXME';
if($@) {
	# AUTHOR_TESTING=1 perl -MTest::Without::Module=Devel::FIXME -w -Iblib/lib t/fixme.t
	diag('Devel::FIXME needed to test for FIXMEs');
	done_testing(1);
} else {
	$ENV{'GATEWAY_INTERFACE'} = 'CGI/1.1';
	$ENV{'REQUEST_METHOD'} = 'GET';
	$ENV{'QUERY_STRING'} = 'fred=wilma';

	# $Devel::FIXME::REPAIR_INC = 1;

	use_ok('CGI::Info');

	# ok($messages[0] !~ /lib\/Geo\/Coder\/Free.pm/);
	cmp_ok(scalar(@messages), '==', 0, 'No FIXMEs found');

	done_testing(3);
}

sub Devel::FIXME::rules {
	sub {
		my $self = shift;
		return shout($self) if $self->{file} =~ /lib\/Geo\/Coder\/Free/;
		return Devel::FIXME::DROP();
	}
}

sub shout {
	my $self = shift;
	push @messages, "# FIXME: $self->{text} at $self->{file} line $self->{line}.\n";
}
