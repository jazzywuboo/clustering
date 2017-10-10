#!/usr/bin/perl
use strict;
use warnings;
use Cwd;

# creates a file with all linking term cui vectors
# input is a linking terms cui file and a file with vectors from a certain time range
# program finds the vectors corresponding to the cui terms and prints them to a file
# output file ends in _v and is ready to be process by vcluster

my $start_time = time;
my ($cui_terms_file, $cui_vectors_file, $base_dir) = SetPaths();
my $LTCs = SaveLTCs();
my $vectors = ExtractVectors();
PrintVectors($vectors);
my $end_time = time - $start_time;
my $execution_time = $end_time/60;
printf("Execution time: %.2f mins\n", $execution_time);

sub PrintUsageNotes {
	print "Usage:\tperl vcluster_converter.pl [cui_terms_file] [cui_vectors_file]\n";
}

sub SetPaths {
	# gets source directory and destination directory from user
	no warnings 'uninitialized';
	my $base_dir = cwd();
	my $cui_terms_file = "$ARGV[0]";
	my $cui_vectors_file = "$ARGV[1]";

	if ($#ARGV < 1 || $#ARGV > 1){
		print "Program takes 2 arguments.\n";
		PrintUsageNotes();
		exit
	}

	if (! -e $cui_terms_file || ! -f $cui_terms_file || ! -e $cui_vectors_file || ! -f $cui_vectors_file){
		if (! -e $cui_terms_file){
			print "Error: $cui_terms_file not found.\n";
		}
		if (! -f $cui_terms_file){
			print "Error: $cui_terms_file must be a file.\n";
		}
		if (! -e $cui_vectors_file){
			print "Error: $cui_vectors_file not found.\n";
		}
		if (! -f $cui_vectors_file){
			print "Error: $cui_vectors_file must be a file.\n";
		}
		PrintUsageNotes();
		exit
	}
	return $cui_terms_file, $cui_vectors_file, $base_dir;
}

sub SaveLTCs {
	# saves cui-term-score information in a hash of structure %LTCs: cui -> term -> score
	my %LTCs;
	open my $fh, '<', "$base_dir/$cui_terms_file" or die "Can't open $base_dir/$cui_terms_file: $!";
	while (my $line = <$fh>) {
		if ($line =~ /^\d+\t\d+.\d+\t(C\d{7})\t.+/){
			my $cui = $1;
			$LTCs{$cui} = 1;	# just using '1' as null value
		}
	}
	close $fh;
	return \%LTCs;
}

sub ExtractVectors {
	# extractors word2vec vectors that correspond to LTC cui's and saves to an array of arrays
	my @vectors;
	my %LTCs = %$LTCs;
	open my $fh, '<', "$base_dir/$cui_vectors_file" or die "Can't open $base_dir/$cui_vectors_file: $!";
	while (my $line = <$fh>){
		if ($line =~ /^(C\d{7})(.+)/){
			my $cui = $1;
			if (exists $LTCs{$cui}){
				my $vector = $2;
				my @vector_vals = ($vector =~ /(-?\d.\d+)/g);
				push @vectors, [@vector_vals];
			}
		}
	}
	close $fh;
	return \@vectors;
}

sub TestCuis {
	my %test_cuis;
	my %LTCs = %$LTCs;
	open my $fh, '<', "$base_dir/$cui_vectors_file" or die "Can't open $base_dir/$cui_vectors_file: $!";
	while (my $line = <$fh>){
		if ($line =~ /^(C\d{7})(.+)/){
			my $cui = $1;
			my $vector = $2;
			my @vector_vals = ($vector =~ /(-?\d.\d+)/g);
			$test_cuis{$cui} = $1;
		}
	}
	close $fh;
	my $found = 0;
	my $not_found = 0;
	foreach my $cui (keys %LTCs){
		if (exists $test_cuis{$cui}){
			$found++;
		}
		else {
			$not_found++;
		}
	}
	print "$found found, $not_found not found.\n";
}

sub PrintVectors {
	# prints dense matrices in format required for CLUTO's vcluster program
	my @vectors = @$vectors;
	my $num_rows = @vectors;
	my $num_columns = @{$vectors[0]};
	my $file_extension = "_v";
	my $vcluster_file = "$cui_vectors_file$file_extension";
	open my $fh, ">", "$base_dir/$vcluster_file" or die "Can't open $base_dir/$vcluster_file: $!";
	print $fh "$num_rows $num_columns\n";
	foreach my $vector (@vectors) {
		print $fh join(' ', @$vector);
		print $fh "\n";
	}
	close $fh;
	print "Vcluster-formatted files located at: $base_dir/$vcluster_file\n";
}

