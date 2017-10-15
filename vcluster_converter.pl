#!/usr/bin/perl
use strict;
use warnings;
use Cwd;

# creates a file with all linking term cui vectors
# input is a linking terms cui file and a file with vectors from a certain time range
# program finds the vectors corresponding to the cui terms and prints them to a file
# output file ends in _v and is ready to be process by vcluster

my $start_time = time;
my ($ltc_file, $vector_file, $base_dir) = SetPaths();
my $linking_terms = SaveLinkingTerms();
my $vectors = ExtractVectors();
PrintVectors($vectors);
my $end_time = time - $start_time;
my $execution_time = $end_time/60;
printf("Execution time: %.2f mins\n", $execution_time);

sub PrintUsageNotes {
	print "Usage:\tperl vcluster_converter.pl [ltc_file] [vector_file]\n";
}

sub SetPaths {
	# gets source directory and destination directory from user
	no warnings 'uninitialized';
	my $base_dir = cwd();
	my $ltc_file = "$ARGV[0]";
	my $vector_file = "$ARGV[1]";

	if ($#ARGV < 1 || $#ARGV > 1){
		print "Program takes 2 arguments.\n";
		PrintUsageNotes();
		exit
	}

	if (! -e $ltc_file || ! -f $ltc_file || ! -e $vector_file || ! -f $vector_file){
		if (! -e $ltc_file){
			print "Error: $ltc_file not found.\n";
		}
		if (! -f $ltc_file){
			print "Error: $ltc_file must be a file.\n";
		}
		if (! -e $vector_file){
			print "Error: $vector_file not found.\n";
		}
		if (! -f $vector_file){
			print "Error: $vector_file must be a file.\n";
		}
		PrintUsageNotes();
		exit
	}
	return $ltc_file, $vector_file, $base_dir;
}

sub SaveLinkingTerms {
	# saves cui-term-score information in a hash of structure %linking_terms: cui -> term -> score
	my %linking_terms;
	open my $fh, '<', "$base_dir/$ltc_file" or die "Can't open $base_dir/$ltc_file: $!";
	while (my $line = <$fh>) {
		if ($line =~ /\d+\t(\d+.\d+)\t(C\d{7})\t.+/){
			my $score = $1;
			my $cui = $2;
			$linking_terms{$cui} = $score;
		}
	}
	close $fh;
	return \%linking_terms;
}

sub ExtractVectors {
	# extractors word2vec vectors that correspond to LTC cui's and saves to an array of arrays
	my %vectors;
	my %linking_terms = %$linking_terms;
	open my $fh, '<', "$base_dir/$vector_file" or die "Can't open $base_dir/$vector_file: $!";
	while (my $line = <$fh>){
		if ($line =~ /^(C\d{7})(.+)/){
			my $cui = $1;
			if (exists $linking_terms{$cui}){
				my $vector = $2;
				my @vector_vals = ($vector =~ /(-?\d.\d+)/g);
				$vectors{$cui} = [@vector_vals];
			}
		}
	}
	close $fh;
	return \%vectors;
}

sub TestSort {
	my %linking_terms = %$linking_terms;
	my %ranked_cuis;
	my @cuis = sort {$linking_terms{$b} <=> $linking_terms{$a}} keys(%linking_terms);
	foreach my $cui (@cuis){
		my $score = $linking_terms{$cui};
		$ranked_cuis{$cui} = $score;
		print "$cui $score\n";
	}
}

sub PrintVectors {
	# prints dense matrices in format required for CLUTO's vcluster program
	my %vectors = %$vectors;
	my $num_rows = keys %vectors;
	my $num_columns = 200;		# change this later
	my $file_extension = "_v";
	my %linking_terms = %$linking_terms;
	my $vcluster_file = "$vector_file$file_extension";

	open my $fh, ">", "$base_dir/$vcluster_file" or die "Can't open $base_dir/$vcluster_file: $!";
	print $fh "$num_rows $num_columns\n";

	my @cuis = sort {$linking_terms{$b} <=> $linking_terms{$a}} keys(%linking_terms);	# prints vectors sorted by ltc score
	foreach my $cui (@cuis){
		if (exists $vectors{$cui}){
			my $vector = @$vectors{$cui};
			print $fh join(' ', @$vector);
			print $fh "\n";
		}
	}
	close $fh;

	print "Vcluster-formatted files located at: $base_dir/$vcluster_file\n";
}
