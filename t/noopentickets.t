#!/usr/bin/env perl

use strict;
use warnings;
use Data::Dumper;
use Test::Most tests => 3;

NOBUGS: {
	SKIP: {
		if($ENV{AUTHOR_TESTING}) {
			eval 'use WWW::RT::CPAN';	# FIXME: use a REST client
			if($@) {
				diag('WWW::RT::CPAN required to check for open tickets');
				skip('WWW::RT::CPAN required to check for open tickets', 3);
			} elsif(my @rc = @{WWW::RT::CPAN::list_dist_active_tickets(dist => 'Geo-Coder-Free')}) {
				ok($rc[0] == 200);
				ok($rc[1] eq 'OK');
				if(defined($rc[2])) {
					my @tickets = @{$rc[2]};

					foreach my $ticket(@tickets) {
						diag($ticket->{id}, ': ', $ticket->{title}, ', broken since ', $ticket->{'broken_in'}[0]);
					}
					ok(scalar(@tickets) == 0);
				} else {
					skip('No tickets have been raised', 1);
				}
			} else {
				diag("Can't connect to rt.cpan.org");
				skip("Can't connect to rt.cpan.org", 3);
			}
		} else {
			diag('Author tests not required for installation');
			skip('Author tests not required for installation', 3);
		}
	}
}
