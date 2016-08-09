#!/usr/bin/env perl

#####################################################################
# maker_checkFusionSplitBetweenTwoBuilds v1 - Jacques Dainat 10/2014 #
#####################################################################

use strict;
use warnings;
use POSIX qw(strftime);
use Carp;
use Getopt::Long;
use IO::File;
use Pod::Usage;
use Statistics::R;
use BILS::Handler::GFF3handler qw(:Ok);
use BILS::Handler::GXFhandler qw(:Ok);
use Bio::Tools::GFF;

my $header = qq{
########################################################
# BILS 2015 - Sweden                                   #  
# jacques.dainat\@bils.se                               #
# Please cite BILS (www.bils.se) when using this tool. #
########################################################
};


my $opt_reffile;
my $opt_plot;
my $opt_nbUTR;
my $opt_bst=undef;
my $opt_utr3=undef;
my $opt_utr5=undef;
my $opt_output=undef;
my $opt_help = 0;
my $DefaultUTRnb=5;

my @copyARGV=@ARGV;
if ( !GetOptions( 'f|gff|ref|reffile=s' => \$opt_reffile,
                  'n|nb|number=i' => \$opt_nbUTR,
                  '3|three|tree_prime_utr' => \$opt_utr3,
                  '5|five|five_prime_utr' => \$opt_utr5,
                  'b|both|bs' => \$opt_bst,
                  'o|out|output=s' => \$opt_output,
                  'p|plot' => \$opt_plot,
                  'h|help!'         => \$opt_help ) )
{
    pod2usage( { -message => 'Failed to parse command line',
                 -verbose => 1,
                 -exitval => 1 } );
}

if ($opt_help) {
    pod2usage( { -verbose => 2,
                 -exitval => 2,
                 -message => "$header\n" } );
}

if ( ! defined($opt_reffile ) or ! ($opt_utr3 or $opt_utr5 or $opt_bst or $opt_plot) ) {
    pod2usage( {
           -message => "$header\nMust specify at least 2 parameters:\nReference data gff3 file (--gff)\nOne UTR option (3, 5 , both, plot)",
           -verbose => 0,
           -exitval => 1 } );
}

# #######################
# # START Manage Option #
# #######################

if (defined($opt_output) ) {
  if (-d $opt_output){
    print "The output directory choosen already exists. Please geve me another Name.\n";exit();
  }
  else{
    mkdir $opt_output;
  }
}

my $ostreamReport;
if (defined($opt_output) ) {
  $ostreamReport=IO::File->new(">".$opt_output."/report.txt" ) or croak( sprintf( "Can not open '%s' for writing %s", $opt_output."/report.txt", $! ));
}
else{
  $ostreamReport = \*STDOUT or die ( sprintf( "Can not open '%s' for writing %s", "STDOUT", $! ));
}
my $string1 = strftime "%m/%d/%Y at %Hh%Mm%Ss", localtime;
$string1 .= "\n\nusage: $0 @copyARGV\n\n";

if (! $opt_nbUTR){
  $opt_nbUTR=$DefaultUTRnb;
}elsif(!($opt_utr3 or $opt_utr5 or $opt_bst)){$string1 .= "The value $opt_nbUTR of the parameter <n> will no be taken into account. Indeed no UTRs option called. (three, five, both).\n";}
if($opt_utr3 or $opt_utr5 or $opt_bst){
  $string1 .= "Genes with more than $opt_nbUTR UTRs will be reported.\n";
}


print $ostreamReport $string1;
if($opt_output){print $string1;}
# #####################################
# # END Manage OPTION  
# #####################################



                                                      #######################
                                                      #        MAIN         #
#                     >>>>>>>>>>>>>>>>>>>>>>>>>       #######################       <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<


# #################################
# # Manage Ouput Directory / File #
# #################################

my $ostreamUTR;
my $ostreamUTRdiscarded;

if (defined($opt_output) ) {

  my $file_in=$opt_reffile;
  $file_in =~ s/.gff.*//g;
  
  #manage name output
  my $utr_type=undef;
  # case no filter so we don't create discarded file output.
  if (! ($opt_utr3 and $opt_utr5 and $opt_bst)){
    $utr_type = $file_in;
     my $nameUTRok=$opt_output."/".$utr_type.".gff";
    $ostreamUTR = Bio::Tools::GFF->new(-file => ">".$nameUTRok) or croak( sprintf( "Can not open '%s' for writing %s", $nameUTRok, $! ) );
  }
  else{  # case with filter so we create discarded file output and a of file output.
    if ($opt_utr3){
      $utr_type = $file_in."3_under".$opt_nbUTR;
    }
    if ($opt_utr5){
      if($utr_type){
         $utr_type.="and_5_under".$opt_nbUTR;
      }else{$utr_type=$file_in."5_under".$opt_nbUTR;}
    }
    if ($opt_bst){
      if($utr_type){
         $utr_type.="and_bothSides_under".$opt_nbUTR;
      }else{$utr_type=$file_in."bothSides_under".$opt_nbUTR;}
    }

  my $nameUTRok=$opt_output."/".$utr_type.".gff";
  $ostreamUTR = Bio::Tools::GFF->new(-file => ">".$nameUTRok) or croak( sprintf( "Can not open '%s' for writing %s", $nameUTRok, $! ) );
  my $ostreamUTRdiscarded=$opt_output."/".$utr_type."over".$opt_nbUTR."s.gff";
  $ostreamUTRdiscarded = Bio::Tools::GFF->new(-file => ">".$ostreamUTRdiscarded) or croak( sprintf( "Can not open '%s' for writing %s", $ostreamUTRdiscarded, $! ) );
  }
}
else { # No output provided, we print everything on screen
  my $ostream  = IO::File->new();
  $ostream->fdopen( fileno(STDOUT), 'w' ) or croak( sprintf( "Can not open STDOUT for writing: %s", $! ) );
  $ostreamUTR = Bio::Tools::GFF->new( -fh => $ostream ) or croak( sprintf( "Can not open STDOUT for writing: %s", $! ) );
  my $ostream_d  = IO::File->new();
  $ostream_d->fdopen( fileno(STDOUT), 'w' ) or croak( sprintf( "Can not open STDOUT for writing: %s", $! ) );
  $ostreamUTRdiscarded = Bio::Tools::GFF->new( -fh => $ostream ) or croak( sprintf( "Can not open STDOUT for writing: %s", $! ) );
}

######################
### Parse GFF input #
my ($hash_omniscient, $hash_mRNAGeneLink) = BILS::Handler::GFF3handler->slurp_gff3_file_JD($opt_reffile);
print("Parsing Finished\n\n");
### END Parse GFF input #
#########################

my %UTRdistribution;
my %UTRbymRNA;
my %UTRoverview;
# #########################################################
# # A.1) Assign utr side if they are not
# #########################################################

foreach my $tag_l3 ( keys %{$hash_omniscient->{'level3'}} ) {
   if($tag_l3 =~ /utr/){
     if ($tag_l3 ne 'three_prime_utr' and $tag_l3 ne 'five_prime_utr') {

       foreach my $id_l2 ( keys %{$hash_omniscient->{'level3'}{$tag_l3}} ){
        
         my $geneID = $hash_mRNAGeneLink->{$id_l2};
         my $feature_l2 = get_feature_l2_from_id_l2_l1($hash_omniscient, $id_l2, $geneID);
         my $strand = $feature_l2->strand();
         my $cds_feature_example =  $hash_omniscient->{'level3'}{'cds'}{$id_l2}[0]; #if utr exists, cds should exists
        
         foreach my $feature_l3 ( @{$hash_omniscient->{'level3'}{$tag_l3}{$id_l2}}){
           if($feature_l3->start <= $cds_feature_example->start){
             if ($strand eq "+" or $strand eq "1"){
               $feature_l3->primary_tag= "five_prime_utr";
             }
             else{$feature_l3->primary_tag= "three_prime_utr";}
           }
           else{
             if ($strand eq "+" or $strand eq "1"){
               $feature_l3->primary_tag= "three_prime_utr";
             }
             else{
               $feature_l3->primary_tag= "five_prime_utr";
             }
           }
         }
       }
     }
   }
}

# #########################################################
# # A.1) Count utr exon by side and total
# #########################################################

foreach my $tag_l2 (keys %{$hash_omniscient->{'level2'}}) {
  foreach my $id_l1 (keys %{$hash_omniscient->{'level2'}{$tag_l2}}) {
    foreach my $feature_l2 (@{$hash_omniscient->{'level2'}{$tag_l2}{$id_l1}}) {

      my $has_an_utr=undef;
      my $id_l2= lc($feature_l2->_tag_value('ID'));
      
      foreach my $tag_l3 (keys %{$hash_omniscient->{'level3'}}) {
        if($tag_l3 =~ /utr/){
          if(exists ($hash_omniscient->{'level3'}{$tag_l3}{$id_l2})){
            $has_an_utr="yes";

            my $nbUTR = $#{$hash_omniscient->{'level3'}{$tag_l3}{$id_l2}}+1; #nb utrs
            $UTRdistribution{$tag_l3}{$nbUTR}++;
            $UTRbymRNA{$tag_l3}{$id_l2}=$nbUTR;
            $UTRoverview{$tag_l3}++;
            if(! exists $UTRbymRNA{'both'}{$id_l2}){
              $UTRbymRNA{'both'}{$id_l2}=$nbUTR;
            }else{$UTRbymRNA{'both'}{$id_l2}+=$nbUTR;}
            
           #   print_omniscient_from_level1_id_list($hash_omniscient,[$geneID],$utr_gff{$tag_l3});
          }
        }
      }
      if(!$has_an_utr){
         $UTRbymRNA{'both'}{$id_l2}=0;
      }
    }  
  }
}

###########################
# compute if on of UTR option called
###########################

###########################
# Overview of UTRs
if($opt_utr3 or $opt_utr5 or $opt_bst){
  # print preliminary results
  my $stringPrint="";
  foreach my $key (keys %UTRoverview) {
     $stringPrint.="There is $UTRoverview{$key} $key\n";
    my $total=0;
    foreach my $value  ( sort {$b <=> $a} keys $UTRdistribution{$key}){
      if($value >= $opt_nbUTR){
        $total+=$UTRdistribution{$key}{$value};
      }
      else{last;}
    }
    $stringPrint.= "There is $total $key cases that have over or equal $opt_nbUTR exons.\n";
  }



###########################
# Main compute
 my @listIDl2discarded;
  my @listIDlok;
  foreach my $tag (keys %UTRbymRNA) {
    foreach my $id_level2 (keys $UTRbymRNA{$tag}){

      # case only opt_utr3
      if ($opt_utr3 and $tag eq "three_prime_utr"){
        if ($UTRbymRNA{$tag}{$id_level2} >= $opt_nbUTR){
          push @listIDl2discarded, $id_level2 ;
        }
        else{push @listIDlok, $id_level2 ;
        }
      }
      # case only opt_utr5
      if ($opt_utr5 and $tag eq "five_prime_utr"){
        if ($UTRbymRNA{$tag}{$id_level2} >=  $opt_nbUTR){
          push @listIDl2discarded, $id_level2 ;
        }
        else{push  @listIDlok, $id_level2;
        }
      }                                           ### REMOVE OPTION BOTH ?
      # case both side together (when added) should be over $opt_nbUTR) 
      if ($opt_bst and $tag eq "both"){
        if ($UTRbymRNA{$tag}{$id_level2} >=  $opt_nbUTR){
          push @listIDl2discarded, $id_level2;
        }
        else{push @listIDlok, $id_level2 ;
        }
      }
      # case both side independant (side 3 and and5 should be over $opt_nbUTR) 

      # case no option print all so put all in @listIDlok
      if(! $opt_utr3 and ! $opt_utr5 and ! $opt_bst) { # in case where no option, We do by default side3 side5 idependant. On sufficiant to discard the mRNA
          push @listIDlok, $id_level2 ;
      }
    }
  }

  # remove duplicate in case several option tends to give the same case
  if(@listIDl2discarded){
    my $sizeList= @listIDl2discarded;
    $stringPrint.= "$sizeList gene discarded\n";
    my @listIDl2discardedUniq = uniq(@listIDl2discarded);
    my $omniscient_discarded = create_omniscient_from_idlevel2list($hash_omniscient, $hash_mRNAGeneLink, \@listIDl2discarded);
    print_omniscient($omniscient_discarded, $ostreamUTRdiscarded);
  }
  if(@listIDlok){
    my $sizeList= @listIDlok;
    $stringPrint.= "$sizeList genes that reach you quality request.\n";
    my @listIDlokUniq = uniq(@listIDlok);
    my $omniscient_ok = create_omniscient_from_idlevel2list($hash_omniscient, $hash_mRNAGeneLink, \@listIDlokUniq);
    print_omniscient($omniscient_ok, $ostreamUTR);
  }

  #Print Info OUtput
  print $ostreamReport $stringPrint;
  if($opt_output){
    print $stringPrint;
  }
}

############################
# Plot distribution if asked
if ($opt_plot){

  foreach my $utr_type (keys %UTRdistribution) {
    
    my $txtFile;
    my $outPlot;
    my $outPlotOver;
    if($opt_output){
      $txtFile = $opt_output."/".$utr_type.".txt";
      $outPlot = $opt_output."/".$utr_type.".pdf";
      $outPlotOver = $opt_output."/".$utr_type."over".$opt_nbUTR.".pdf";
    }else{
      $txtFile = $utr_type.".txt";
      $outPlot = $utr_type.".pdf";
      $outPlotOver = $utr_type."over".$opt_nbUTR."pdf";
    }
    #print file thtat will be read by R
    open(FH, ">".$txtFile) || die "Erreur E/S:$!\n";
    my $firstLine="yes";
    foreach my $value (keys $UTRdistribution{$utr_type}) {
      if($firstLine){
         print FH $value."\t".$UTRdistribution{$utr_type}{$value};
      }else{
         print FH "\n".$value."\t".$UTRdistribution{$utr_type}{$value};
      }
    }
    close FH;

  my $R = Statistics::R->new() or die "Problem with R : $!\n";

  #R command
  $R->send(
        qq`
        listValues=as.matrix(read.table("$txtFile", sep="\t", he=F)) ##///!!!\\\\\
        legendToDisplay=paste("Number of value used : ",length(listValues))
        listValueMoreThan <- listValues[listValues[,1]>5,]

        pdf("$outPlot")
        plot(listValues[,2]~listValues[,1], xlab="Contig size", ylab="Frequency", main="Size distribution of $utr_type")
        dev.off()
        
        pdf("$outPlotOver")
        plot(listValueMoreThan[,2]~listValueMoreThan[,1], xlab="Contig size", ylab="Frequency", main="Size distribution of $utr_type over 5")
        dev.off()`
            );

  # Close the bridge
  $R->stopR();

  # Delete temporary file
  unlink "$txtFile";

  }

}

#######################################################################################################################
        ####################
         #     methods    #
          ################
           ##############
            ############
             ##########
              ########
               ######
                ####
                 ##

sub uniq {
    my %seen;
    grep !$seen{$_}++, @_;
}

__END__


=head1 NAME

maker_manageUTR.pl - Detect the genes containing too much UTR's exon according to a choosen threshold.
If no UTR option (3, 5, 3 and 5, both) is given the threshold will be not used. 
option 3 and 5 together is different of "both". In the first case the gene is discarded if either the 3' or the 5' UTR contains more exon than the threshold given.
In the second case, will be discarded only the genes where the addition of UTR's exon of both side is over the threshold given.

=head1 SYNOPSIS

    ./maker_manageUTR.pl --ref=infile --three --five -p --out=outFile 
    ./maker_manageUTR.pl --help

=head1 OPTIONS

=over 8

=item B<--gff>, B<--ref>, B<--reffile> or B<-f>

Input GFF3 file correponding to gene build.

=item B<-n>, B<--nb> or B<--number>

Threshold of exon's number of the UTR. Over or equal to this threshold, the UTR will be discarded. Default value is 5.

=item B<-3>, B<--three> or B<--tree_prime_utr>

The threshold of the option <n> will be applied on the 3'UTR.

=item B<-5>, B<--five> or B<--five_prime_utr>

The threshold of the option <n> will be applied on the 5'UTR.

=item B<-b>, B<--both> or B<--bs>

The threshold of the option <n> will be applied on genes where the number of UTR exon (3' and 5' additioned) is over it.

=item  B<--p>, B<--plot> or B<-o>

Allows to create an histogram in pdf of UTR sizes distribution.

=item  B<--out>, B<--output> or B<-o>

Output gff3 file where the gene incriminated will be write.

=item B<--help> or B<-h>

Display this helpful text.

=back

=cut