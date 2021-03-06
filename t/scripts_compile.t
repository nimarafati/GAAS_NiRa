#!/usr/bin/env perl

use strict;
use warnings;

=head1 DESCRIPTION

Test to see if all script in the bin file can be compiled without error.

=cut


################################################################################
#   set number of test according to number of scripts
my $nb_test=0;
my %perl_blacklist;

BEGIN{
	## BLACK listed list of perl scripts
	%perl_blacklist = ( "gaas_create_preautomated_report.pl" => 0
											  );

  opendir (DIR, "bin") or die $!;
  while (my $file = readdir(DIR)) {
     # Use a regular expression to ignore files beginning with a period
     next if ($file =~ m/^\./);
		 next if ! ($file =~ /\.pl$/);
		 next if exists ($perl_blacklist{$file});
     #add exe file
     $nb_test++;
  }
  closedir(DIR);
}
#
################################################################################

use Test::More tests => $nb_test ;


# foreach script in the bin, let run the test
opendir (DIR, "bin") or die $!;
while (my $file = readdir(DIR)) {
   # Use a regular expression to ignore files beginning with a period
   next if ($file =~ m/^\./);
	 next if ! ($file =~ /\.pl$/);
	 next if exists ($perl_blacklist{$file});
   print "bin/$file -h 1>/dev/null\n";
   #run test - check the script can run calling the help.
   ok( system("bin/$file -h 1>/dev/null") == 0, "test $file")
}
closedir(DIR);
