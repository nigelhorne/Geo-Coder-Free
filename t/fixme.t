#!perl -w

# Ensure that there are no FIXMEs in the code

use strict;
use warnings;
use Test::Most;

my @messages;

if($ENV{AUTHOR_TESTING}) {
	is($INC{'Devel/FIXME.pm'}, undef, "Devel::FIXME isn't loaded yet");

	eval 'use Devel::FIXME';
	if($@) {
		diag('Devel::FIXME needed to test for FIXMEs');
		done_testing(1);
	} else {
		# $Devel::FIXME::REPAIR_INC = 1;

		use_ok('Geo::Coder::Free');

		# ok($messages[0] !~ /lib\/Geo\/Coder\/Free.pm/);
		ok(scalar(@messages) == 0);

		done_testing(3);
	}
} else {
	plan(skip_all => 'Author tests not required for installation');
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

