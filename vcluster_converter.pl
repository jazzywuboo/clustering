#!/usr/bin/perl
use strict;
use warnings;
use Cwd;

## Main
my $start_time = time;
my ($cui_terms_file, $cui_vectors_file, $base_dir) = GetArgs();
my $cui_info = SaveCuiInfo();
my $vectors = ExtractVectors();
PrintVectors($vectors);
my $end_time = time - $start_time;
my $execution_time = $end_time/60;
printf("Execution time: %.2f mins\n", $execution_time);

sub PrintUsageNotes {
	print "Usage:\tperl vcluster_converter.pl [cui_terms_file] [cui_vectors_file]\n";
}

sub GetArgs {
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

sub SaveCuiInfo {
	my %cui_info;
	open my $fh, '<', "$base_dir/$cui_terms_file" or die "Can't open $base_dir/$cui_terms_file: $!";
	while (my $line = <$fh>) {
		if ($line =~ /^\d+\t(\d+.\d+)\t(C\d{7})\t(.+)/){
			my $score = $1;
			my $cui = $2;
			my $term = $3;
			$cui_info{$cui}{$term} = $score;
		}
	}
	close $fh;
	return \%cui_info;
}

sub ExtractVectors {
	# extractors word2vec vectors from each file
	my @vectors;
	my %cui_info = %$cui_info;
	open my $fh, '<', "$base_dir/$cui_vectors_file" or die "Can't open $base_dir/$cui_vectors_file: $!";
	while (my $line = <$fh>){
		if ($line =~ /^(C\d{7})(.+)/){
			my $cui = $1;
			if (exists $cui_info{$cui}){
				my $vector = $2;
				my @vector_vals = ($vector =~ /(-?\d.\d+)/g);
				push @vectors, [@vector_vals];
			}
		}
	}
	close $fh;
	return \@vectors;
}

sub PrintVectors {
	# prints dense matrices in format for vcluster program in CLUTO
	my @vectors = @$vectors;
	my $num_rows = @vectors;
	my $num_columns = @{$vectors[0]};
	my $vcluster_file = "$cui_vectors_file.vcluster";
	open my $fh, ">", "$base_dir/$vcluster_file" or die "Can't open $base_dir/$vcluster_file: $!";
	print $fh "$num_rows $num_columns\n";
	foreach my $vector (@vectors) {
		print $fh join(' ', @$vector);
		print $fh "\n";
	}
	close $fh;
	print "Vcluster-formatted files located at: $base_dir/$vcluster_file\n";

}
