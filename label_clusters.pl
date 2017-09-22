#!/usr/bin/perl
use strict;
use warnings;
use Cwd;

## Main
my $start_time = time;
my ($cui_terms_dir, $unformatted_dir, $formatted_dir, $clustered_dir) = GetArgs();
my $cui_info = ExtractCuiInfo();
my $vector_indices = ExtractVectorIndeces();		# file -> vector_index -> @vector_value
my $clustered_vectors = ExtractClusteredVectors();
my $cui_vector_indices = ExtractCuiVectorIndices();
my $centroid_values = CalculateCentroids();
LabelCentroids();

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

sub ExtractCuiInfo {
	my %cui_info;
	opendir my $dh, $cui_terms_dir or die "Can't open $cui_terms_dir: $!";
	while (my $file = readdir($dh)) {
		next if ($file =~ /^\./);
		next if -d $file;
		open my $fh, "$cui_terms_dir/$file" or die "Can't open $cui_terms_dir/$file: $!";
		while (my $line = <$fh>) {
			if ($line =~ /^\d+\t(\d+.\d+)\t(C\d{7})\t(.+)/){
				my $score = $1;
				my $cui = $2;
				my $term = $3;
				$cui_info{$cui}{$term} = $score;
			}
		}
		close $fh;
	}
	closedir $dh;
	return \%cui_info;
}

sub ExtractCuiVectorIndices {
	# creates hash to look up cuis and terms by their vector index
	my %cui_vector_indices;
	opendir my $dh, $unformatted_dir or die "Can't open $unformatted_dir: $!";
	while (my $file = readdir($dh)) {
		next if ($file =~ /^\./);
		next if -d $file;
		open my $fh, "$unformatted_dir/$file" or die "Can't open $unformatted_dir/$file: $!";
		my $vector_index = 0;
		while (my $line = <$fh>) {
			if ($line =~ /^(C\d{7}).+/){
				my $cui = $1;
				$cui_vector_indices{$file}{$vector_index} = $cui;
				$vector_index++;
			}
		}
		close $fh;
	}
	closedir $dh;
	return \%cui_vector_indices;
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
			push @{$clustered_vectors{$file}{$cluster_index}}, $vector_index;
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
	my %vector_indices =%$vector_indices;
	my %centroid_values;
	my $num_columns = 200;	# change to pass in value

	foreach my $file (keys %clustered_vectors){
		foreach my $cluster_index (keys $clustered_vectors{$file}){
			my $vectors_per_cluster = 0;
			$centroid_values{$file}{$cluster_index} = [(0) x $num_columns];
			foreach my $vector_index (@{$clustered_vectors{$file}{$cluster_index}}){
				$vectors_per_cluster++;
				my @vector = @{$vector_indices{$file}{$vector_index}};
				foreach my $i (0 .. $#vector){
					$centroid_values{$file}{$cluster_index}[$i] += $vector[$i];
				}
			}
			foreach my $i (0.. $num_columns-1){
				$centroid_values{$file}{$cluster_index}[$i] /= $vectors_per_cluster;
			}
		}
	}
	return \%centroid_values;
}

sub LabelCentroids {
	# labels cluster centroid with vector closest to the centroid, determined with cosine similarity 
	my %centroid_values = %$centroid_values;
	my %cui_vector_indices = %$cui_vector_indices;
	my %vector_indices = %$vector_indices;
	my %clustered_vectors = %$clustered_vectors;
	my %cui_info = %$cui_info;
	my %labelled_centroids;

	foreach my $file (keys %centroid_values){
		foreach my $cluster_index (keys $centroid_values{$file}){
			my $centroid_vector_index;
			my $min_cos_sim = 10;	# arbitrarily large value
			my @centroid = @{$centroid_values{$file}{$cluster_index}};
			foreach my $vector_index (@{$clustered_vectors{$file}{$cluster_index}}){
				my @vector = @{$vector_indices{$file}{$vector_index}};
				my $cos_sim = CosSim(\@centroid, \@vector);
				if ($cos_sim < $min_cos_sim){
					$min_cos_sim = $cos_sim;
					$centroid_vector_index = $vector_index;
				}
			}
			my $cui = $cui_vector_indices{$file}{$centroid_vector_index};
			$labelled_centroids{$file}{$cluster_index} = $cui;
		}
	}
	print Dumper(\%labelled_centroids);
	return \%labelled_centroids;
}


sub CosSim {
	# calculates cosine similarity between two vectors (aka the dot product)
	# cosine similarity forumla (Vector a, Vector b):
	# (a * b) / (|a|*|b|)
	my ($a, $b) = (@_);
	my @a = @$a;
	my @b = @$b;
	my $numerator;
	my $a_sq_sum;
	my $b_sq_sum;

	foreach my $i (0 .. $#a){
		$numerator += $a[$i]*$b[$i];
		$a_sq_sum += $a**2;
		$b_sq_sum += $b**2;
	}

	my $denominator = sqrt($a_sq_sum)*sqrt($b_sq_sum);
	my $cos_sim = $numerator/$denominator;
	return $cos_sim;
}

