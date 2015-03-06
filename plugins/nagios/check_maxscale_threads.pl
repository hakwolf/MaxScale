#!/usr/bin/perl
#
#
#
# This file is distributed as part of the MariaDB Corporation MaxScale. It is free
# software: you can redistribute it and/or modify it under the terms of the
# GNU General Public License as published by the Free Software Foundation,
# version 2.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 51
# Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#
# Copyright MariaDB Corporation Ab 2013-2015
#
#

#
# @file check_maxscale_threads.pl - Nagios plugin for MaxScale threads and events
#
# Revision History
#
# Date         Who                     Description
# 06-03-2015   Massimiliano Pinto      Initial implementation
#

#use strict;
#use warnings;
use Getopt::Std;

my %opts;
my $TIMEOUT = 15;  # we don't want to wait long for a response
my %ERRORS = ('UNKNOWN' , '3',
              'OK',       '0',
              'WARNING',  '1',
              'CRITICAL', '2');

my $curr_script = "$0";
$curr_script =~ s{.*/}{};

sub usage {
	my $rc = shift;

	print <<"EOF";
MaxScale monitor checker plugin for Nagios

Usage: $curr_script [-r <resource>] [-H <host>] [-P <port>] [-u <user>] [-p <pass>] [-m <maxadmin>] [-h]

Options:
       -r <resource>	= threads
       -h		= provide this usage message
       -H <host>	= which host to connect to
       -P <port>	= port to use
       -u <user>	= username to connect as
       -p <pass>	= password to use for <user> at <host>
       -m <maxadmin>	= /path/to/maxadmin
EOF
	exit $rc;
}

%opts =(
	'r' => 'threads',         	# default maxscale resource to show
	'h' => '',                      # give help
	'H' => 'localhost',		# host
	'u' => 'root',			# username
	'p' => '',			# password
	'P' => 6603,			# port
	'm' => '/usr/local/skysql/maxscale/bin/maxadmin',	# maxadmin
	);
getopts('r:hH:u:p:P:m:', \%opts)
    or usage( $ERRORS{"UNKNOWN"} );
usage( $ERRORS{'OK'} ) if $opts{'h'};

my $MAXADMIN_RESOURCE =  $opts{'r'};
my $MAXADMIN = $opts{'m'};
-x $MAXADMIN or
    die "$curr_script: Failed to find required tool: $MAXADMIN. Please install it or use the -m option to point to another location.";

my ( $state, $status ) = ( "OK", 'maxadmin ' . $MAXADMIN_RESOURCE .' succeeds.' );

# Just in case of problems, let's not hang Nagios
$SIG{'ALRM'} = sub {
     print ("UNKNOWN: No response from MaxScale server (alarm)\n");
     exit $ERRORS{"UNKNOWN"};
};
alarm($TIMEOUT);

my $command = $MAXADMIN . ' -h ' . $opts{'H'} . ' -u ' . $opts{'u'} . ' -p "' . $opts{'p'} . '" -P ' . $opts{'P'} . ' ' . "show " . $MAXADMIN_RESOURCE;

#print "maxadmin command: $command\n";

open (MAXSCALE, "$command 2>&1 |")
   or die "can't get data out of Maxscale: $!";

my $hostname = qx{hostname}; chomp $hostname;
my $waiting_backend = 0;
my $service;
my $start_output = 0;
my $n_threads = 0;
my $p_threads = 0;
my $performance_data="";


my $resource_type = $MAXADMIN_RESOURCE;
chop($resource_type);

my $resource_match = ucfirst("$resource_type Name");

my $historic_thread_load_average = 0;
my $current_thread_load_average = 0;

my %thread_data;
my %event_data;

my $start_queue_len = 0;

while ( <MAXSCALE> ) {
    chomp;

    if ( /Unable to connect to MaxScale/ ) {
        printf "CRITICAL: $_\n";
	close(MAXSCALE);
        exit(2);
    }

	if ( /Historic Thread Load Average/) {
                my $str;
                my @data_row = split(':', $_);
                foreach my $val (@data_row) {
                        $str = $val;
                        $str =~ s/^\s+|\s+$//g;
                }
		chop($str);
                $historic_thread_load_average = $str;
	}

	if (/Current Thread Load Average/) {
                my $str;
                my @data_row = split(':', $_);
                foreach my $val (@data_row) {
                        $str = $val;
                        $str =~ s/^\s+|\s+$//g;
                }
		chop($str);
                $current_thread_load_average = $str;
	}

	if (/Minute Average/) {
                my $str;
		my $in_str;
                my @data_row = split(',', $_);
                foreach my $val (@data_row) {
			my ($i,$j)= split(':', $val);
                       	$i =~ s/^\s+|\s+$//g;
                       	$j =~ s/^\s+|\s+$//g;
			if ($start_queue_len) {
				$event_data{$i} = $j;
			} else {
				$thread_data{$i} = $j;
			}
		}
	}

	if ( /Pending event queue length averages/) {
		$start_queue_len = 1;
		next;
	}

    if ( ! /^\s+ID/ ) {
	#printf $_ ."\n";
    } else {
	#printf "[$_]" ."\n";
	$start_output = 1;
	next;
    }
    if ($start_output && /^\s+\d/) {
	#printf "Thread [$_]" . "\n";
	$n_threads++;
	if (/Processing/) {
		$p_threads++;
	}
    }
}

close(MAXSCALE);


open( MAXSCALE, "/servers/maxinfo/bin/maxadmin -h 127.0.0.1 -P 8444 -uadmin -pskysql show epoll 2>&1 |" )
   or die "can't get data out of Maxscale: $!";

my $queue_len = 0;

while ( <MAXSCALE> ) {
    chomp;
	if ( ! /Current event queue length/ ) {
		next;
	} else {
		my $str;
		my @data_row = split(':', $_);
		foreach my $val (@data_row) {
			$str = $val;
			$str =~ s/^\s+|\s+$//g;
		}
		$queue_len = $str;

		last;
	}
}

my $performance_data = "";
my $performance_data_thread = "";
my $performance_data_event = "";

my $in_str;
my $in_key;
my $in_val;

my @new_thread_array = @thread_data{'15 Minute Average', '5 Minute Average', '1 Minute Average'};
my @new_event_array = @event_data{'15 Minute Average', '5 Minute Average', '1 Minute Average'};

$performance_data_thread = join(';', @new_thread_array);
$performance_data_event = join(';', @new_event_array);

$performance_data .= "threads=$historic_thread_load_average;$current_thread_load_average avg_threads=$performance_data_thread avg_events=$performance_data_event";

if ($p_threads < $n_threads) {
	printf "OK: Processing threads: %d/%d Events: %d | $performance_data\n", $p_threads, $n_threads, $queue_len;
	close(MAXSCALE);
	exit 0;
} else {
	printf "WARNING: Processing threads: %d/%d Events: %d | $performance_data\n", $p_threads, $n_threads, $queue_len;
	close(MAXSCALE);
	exit 1;
}

