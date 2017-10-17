#!/usr/bin/perl
use strict;
use warnings;
use Cwd;

# creates a file with all linking term cui vectors
# input is a linking terms cui file and a file with vectors from a certain time range
# program finds the vectors corresponding to the cui terms and prints them to a file
# output file ends in _v and is ready to be process by vcluster

my ($ltc_file, $vector_file, $base_dir) = SetPaths();
my ($cui_terms, $cui_scores) = SaveLinkingTermInfo();
my ($reduced_cui_vectors, $reduced_cui_terms, $reduced_cui_scores) = ExtractVectors();
my $cui_rankings = DetermineCuiRankings();
PrintVectors();
PrintNewLTCFile();

sub PrintUsageNotes {
	print "Usage:\tperl vcluster_converter.pl [ltc_file] [vector_file] [opt_data_dir]\n";
}

sub SetPaths {
	# gets source directory and destination directory from user
	no warnings 'uninitialized';
	my $base_dir = cwd();
	my $ltc_file = $ARGV[0];
	my $vector_file = $ARGV[1];
	my $opt_data_dir = $ARGV[2];

	if ($#ARGV < 2 || $#ARGV > 3){
		print "Program requires 2 arguments; 3rd is optional.\n";
		PrintUsageNotes();
		exit
	}

	if (-e $opt_data_dir) {
		$ltc_file = 	"$opt_data_dir/$ltc_file";
		$vector_file = 	"$opt_data_dir/$vector_file";
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

sub SaveLinkingTermInfo {
	# saves cui-term-score information in a hash of structure %linking_terms: cui -> term -> score
	my %cui_terms;
	my %cui_scores;
	open my $fh, '<', "$base_dir/$ltc_file" or die "Can't open $base_dir/$ltc_file: $!";
	while (my $line = <$fh>) {
		if ($line =~ /\d+\t(\d+.\d+)\t(C\d{7})\t(.+)/){
			my $score = $1;
			my $cui = $2;
			my $term = $3;
			$cui_terms{$cui} = $term;
			$cui_scores{$cui} = $score;
		}
	}
	close $fh;
	return \%cui_terms, \%cui_scores;
}

sub ExtractVectors {
	# extractors word2vec vectors that correspond to LTC cui's and saves to an array of arrays
	my %reduced_cui_vectors;
	my %cui_terms = %$cui_terms;
	my %cui_scores = %$cui_scores;
	my %reduced_cui_terms;
	my %reduced_cui_scores;

	open my $fh, '<', "$base_dir/$vector_file" or die "Can't open $base_dir/$vector_file: $!";
	while (my $line = <$fh>){
		if ($line =~ /^(C\d{7})(.+)/){
			my $cui = $1;
			if (exists $cui_terms{$cui}){
				my $vector = $2;
				my @vector_vals = ($vector =~ /(-?\d.\d+)/g);
				$reduced_cui_vectors{$cui} = [@vector_vals];

				my $term = $cui_terms{$cui};
				my $score = $cui_scores{$cui};

				$reduced_cui_terms{$cui} = $term;
				$reduced_cui_scores{$cui} = $score;
			}
		}
	}
	close $fh;
	return \%reduced_cui_vectors, \%reduced_cui_terms, \%reduced_cui_scores;
}

sub DetermineCuiRankings {
	my @cui_rankings;
	my %reduced_cui_scores = %$reduced_cui_scores;
	my @cuis = sort {$reduced_cui_scores{$b} <=> $reduced_cui_scores{$a}} keys(%reduced_cui_scores);	# sorts cuis by score
	foreach my $cui (@cuis){
		push @cui_rankings, $cui;
	}
	return \@cui_rankings;
}

sub PrintVectors {
	# prints dense matrices in format required for CLUTO's vcluster program
	my %reduced_cui_vectors = %$reduced_cui_vectors;
	my $num_rows = keys %reduced_cui_vectors;
	my $num_columns = 200;		# change this later
	my $file_extension = "_v";
	my %reduced_cui_terms = %$reduced_cui_terms;
	my %reduced_cui_scores = %$reduced_cui_scores;
	my $vcluster_file = "$vector_file$file_extension";
	my @cui_rankings = @$cui_rankings;

	open my $fh, ">", "$base_dir/$vcluster_file" or die "Can't open $base_dir/$vcluster_file: $!";
	print $fh "$num_rows $num_columns\n";

	foreach my $cui (@cui_rankings){
		my $vector = @$reduced_cui_vectors{$cui};
		print $fh join(' ', @$vector);
		print $fh "\n";
	}
	close $fh;
	print "Vcluster-formatted files located at: $base_dir/$vcluster_file\n";
}

sub PrintNewLTCFile {
	my %reduced_cui_terms = %$reduced_cui_terms;
	my %reduced_cui_scores = %$reduced_cui_scores;
	my $new_ltc_file = $ltc_file;
	$new_ltc_file =~ s/.*\/(.*)/$1/;
	my $file_extension = "_reduced";
	$new_ltc_file = "$ltc_file$file_extension";
	my @cui_rankings = @$cui_rankings;

	open my $fh, ">", "$base_dir/$new_ltc_file" or die "Can't open $base_dir/$new_ltc_file: $!";
	foreach my $cui (@cui_rankings){
		my $score = $reduced_cui_scores{$cui};
		my $term = $reduced_cui_terms{$cui};
		print $fh "$score\t$cui\t$term\n";
	}
	close $fh;
}
