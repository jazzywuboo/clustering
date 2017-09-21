#!/usr/bin/perl
use strict;
use warnings;
use Cwd;

## Main
my $start_time = time;
my ($cui_terms_dir, $unformatted_dir, $formatted_dir, $clustered_dir) = GetArgs();

my $vector_indices = ExtractVectorIndeces();		# file -> vector_index -> @vector_value
my $clustered_vectors = ExtractClusteredVectors();
CalculateCentroids();
PrintExecutionTime();

sub PrintExecutionTime {
	my $execution_time = (time - $start_time)/60;
	printf("Execution time: %.2f minutes\n", $execution_time);
}

sub PrintUsageNotes {
	print "Usage: perl label_clusters.pl [cui_terms_dir] [unformatted_vectors_dir] [formatted_vectors_dir] [clustered_vectors_dir]\n";
}

sub GetArgs {
	# gets source directory and destination directory from user
	no warnings 'uninitialized';

	if ( $#ARGV < 3) {
		print "Error: fewer than 4 arguments provided.\n";
		PrintUsageNotes();
		exit
	}

	my $base_dir = cwd();
	my $cui_terms_dir = "$base_dir/$ARGV[0]";
	my $unformatted_dir = "$base_dir/$ARGV[1]";
	my $formatted_dir = "$base_dir/$ARGV[2]";
	my $clustered_dir = "$base_dir/$ARGV[3]";

	if (!(-e $cui_terms_dir) or !(-e $unformatted_dir) or !(-e $formatted_dir) or !(-e $clustered_dir)
		or -f $cui_terms_dir or -f $unformatted_dir or -f $formatted_dir or -f $clustered_dir){
		print "Invalid filepaths.\n";
		PrintUsageNotes();
		exit
	}

	return $cui_terms_dir, $unformatted_dir, $formatted_dir, $clustered_dir;
}

sub ExtractVectorIndeces {
	# gets the vector index (line number in file) for each vector from the formatted vector files that are input into vcluster
	# returns a hash with keys as file/vector index and value as vector array
	my %vector_indices;
	opendir my $dh, $formatted_dir or die "Can't open $formatted_dir: $!";
	while (my $file = readdir($dh)) {
		next if ($file =~ /^\./);
		next if -d $file;
		open my $fh, "$formatted_dir/$file" or die "Can't open $formatted_dir/$file: $!";
		my $vector_index = -1;			# starts vector index at 0
		while (my $line = <$fh>) {
			if ($vector_index > -1){	# skips first line of input - [#rows] [#columns]
				my $vector = $line;
				my @vector_vals = ($vector =~ /(-?\d.\d+)/g);
				$vector_indices{$file}{$vector_index} = [@vector_vals];
			}
			$vector_index++;
		}
		close $fh;
	}
	closedir $dh;
	return \%vector_indices;
}

sub ExtractClusteredVectors {
	# extracts results of clustering
	my %vector_indices = %$vector_indices;
	my %clustered_vectors;
	opendir my $dh, $clustered_dir or die "Can't open $clustered_dir: $!";
	while (my $file = readdir($dh)) {
		next if ($file =~ /^\./);
		next if -d $file;	
		open my $fh, "$clustered_dir/$file" or die "Can't open $clustered_dir/$file: $!";
		my $vector_index = 0;
		while (my $line = <$fh>){
			my $cluster_index = $line;
			$cluster_index =~ s/\s+//g;
			$file =~ s/.clustering.\d+//;
			my @vector = $vector_indices{$file}{$vector_index};
			push @{$clustered_vectors{$file}{$cluster_index}}, @vector;
			$vector_index++;
		}
		close $fh;	
	}
	closedir $dh;
	return \%clustered_vectors;
}

sub CalculateCentroids {
	# calculates the "centroid" (average value of all vectors) for a cluster
	my %clustered_vectors = %$clustered_vectors;
	my %centroid_values;
	my $num_columns = 200;	# change to pass in value

	foreach my $file (keys %clustered_vectors){
		foreach my $cluster_index (keys $clustered_vectors{$file}){
			my $num_vectors;
			$centroid_values{$file}{$cluster_index} = [(0) x $num_columns];
			foreach my $vector (@{$clustered_vectors{$file}{$cluster_index}}){
				$num_vectors++;
				my @vector = @$vector;
				foreach my $i (0 .. $num_columns-1){
					$centroid_values{$file}{$cluster_index}[$i] += $vector[$i];
				}
			}
			foreach my $i (0.. $num_columns-1){
				$centroid_values{$file}{$cluster_index}[$i] /= $num_vectors;
			}
		}
	}
	return \%centroid_values;
}
