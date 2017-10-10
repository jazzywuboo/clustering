#!/usr/bin/perl
use strict;
use warnings;
use Cwd;
use Data::Dumper;

# input file: result file from CLUTO's vcluster program (file ends in _v.clustering.n where n = num clusters)
# input file format: each line contains a cluster index, with line number corresponding to vector index

# $cui{$term} = $score 		cui -> term -> score
# @ltc_vectors = @vector  	index -> vector

# @ltcs     				index -> linking term cuis
# @clusters 				index -> cluster


my $start_time = time;
my ($base_dir, $ltc_file, $vector_file, $clustered_file, $all_cuis_file, $num_clusters) = GetArgs();
my $ltc_dict = ExtractLTCInfo();			# cui -> term -> score
my $ltc_vectors = ExtractLTCVectors();			# index -> vector
my $ltc_indices = DetermineLTCIndices();	# index -> cui
my $clustered_vectors = ExtractClusteredVectors();
my $centroid_values = CalculateCentroids();
my $labelled_centroids = LabelCentroids();
PrintResults();
PrintExecutionTime();

sub PrintExecutionTime {
	my $execution_time = (time - $start_time)/60;
	printf("Execution time: %.2f minutes\n", $execution_time);
}

sub PrintUsageNotes {
	print "Usage: perl label_clusters.pl [ltc_file] [vector_file] [clustered_file] [all_cuis_file]\n";
}

sub GetArgs {
	# gets source directory and destination directory from user
	no warnings 'uninitialized';
	my $base_dir = cwd();
	my $ltc_file = $ARGV[0];
	my $vector_file = $ARGV[1];
	my $clustered_file = $ARGV[2];
	my $all_cuis_file = $ARGV[3];

	if ($#ARGV < 3 || $#ARGV > 3){
		print "Program takes 4 arguments.\n";
		PrintUsageNotes();
		exit
	}
	if (! -e $all_cuis_file || ! -e $ltc_file || ! -f $ltc_file || ! -e $vector_file || ! -f $vector_file || ! -e $clustered_file || ! -f $clustered_file){
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
		if (! -e $clustered_file){
			print "Error: $clustered_file not found.\n";
		}
		if (! -f $clustered_file){
			print "Error: $clustered_file must be a file.\n";
		}
		if (! -e $all_cuis_file){
			print "Error: $all_cuis_file not found.\n";
		}
		PrintUsageNotes();
		exit
	}
	my $num_clusters;
	if ($clustered_file =~ /.*clustering\.(\d+)/){
		$num_clusters = $1;
	}

	return $base_dir, $ltc_file, $vector_file, $clustered_file, $all_cuis_file, $num_clusters;
}

sub DetermineLTCIndices {
	# extractors word2vec vectors that correspond to LTC cui's and saves to an array of arrays
	my @ltc_indices;
	my %ltc_dict = %$ltc_dict;
	open my $fh, '<', "$base_dir/$all_cuis_file" or die "Can't open $base_dir/$all_cuis_file: $!";
	while (my $line = <$fh>){
		if ($line =~ /^(C\d{7}).+/){
			my $cui = $1;
			if (exists $ltc_dict{$cui}){
				push @ltc_indices, $cui;
			}
		}
	}
	close $fh;
	return \@ltc_indices;
}

sub ExtractLTCInfo {
	# saves a hash with cui/term dictionary
	my %ltc_dict;
	open my $fh, '<', "$base_dir/$ltc_file" or die "Can't open $base_dir/$ltc_file: $!";
	while (my $line = <$fh>) {
		if ($line =~ /^\d+\t(\d+.\d+)\t(C\d{7})\t(.+)/){
			my $score = $1;
			my $cui = $2;
			my $term = $3;
			$ltc_dict{$cui} = $term;
		}
	}
	close $fh;
	return \%ltc_dict;
}

sub ExtractLTCVectors {
	# creates array of linking term cuis; array index is vector index
	my %ltc_dict = %$ltc_dict;
	my @ltc_vectors;
	open my $fh, '<', "$base_dir/$vector_file" or die "Can't open $base_dir/$vector_file: $!";
	my $line_num = 0;
	while (my $line = <$fh>) {
		if ($line_num > 0){
			my @vector = split (' ', $line);
			push @ltc_vectors, [@vector];
		}
		$line_num++;
	}
	close $fh;
	return \@ltc_vectors;
}

sub ExtractClusteredVectors {
	# extracts results of clustering
	# change this to array of arrays later by initializing an array with num_clusters number of indices
	my %clustered_vectors;
	open my $fh, '<', "$clustered_file" or die "Can't open $clustered_file: $!";
	my $vector_index = 0;
	while (my $line = <$fh>){
		my $cluster_index = $line;
		$cluster_index =~ s/\s+//;
		$clustered_file =~ s/.clustering.\d+//;
		push @{$clustered_vectors{$cluster_index}}, $vector_index;
		$vector_index++;
	}
	close $fh;
	return \%clustered_vectors;
}

sub CalculateCentroids {
	# calculates the "centroid" (average value of all ltc_vectors) for a cluster
	my %clustered_vectors = %$clustered_vectors;
	my @ltc_vectors = @$ltc_vectors;
	my %centroid_values;
	my $num_columns = @{$ltc_vectors[0]};
	my $num_vectors = $#ltc_vectors;

	foreach my $cluster_index (sort {$a <=> $b} keys %clustered_vectors){
		my $vectors_per_cluster = 0;										# counter for vectors per cluster
		$centroid_values{$cluster_index} = [(0) x $num_columns];			# initialize centroid values to 0
		foreach my $vector_index (@{$clustered_vectors{$cluster_index}}){	# for each vector
			$vectors_per_cluster++;											# increment vectors per cluster
			my @vector = @{$ltc_vectors[$vector_index]};						# get vector from ltc_vectors
			foreach my $col (0 .. $num_columns-1){ 							# add vector to centroid values for cluster
				$centroid_values{$cluster_index}[$col] += $vector[$col];
			}
		}
		foreach my $col (0.. $num_columns-1){
			$centroid_values{$cluster_index}[$col] /= $vectors_per_cluster;
		}
	}
	return \%centroid_values;
}

sub LabelCentroids {
	# labels cluster centroid with vector closest to the centroid, determined with cosine similarity 
	my %centroid_values = %$centroid_values;
	my @ltc_indices = @$ltc_indices;
	my @ltc_vectors = @$ltc_vectors;
	my %clustered_vectors = %$clustered_vectors;
	my %ltc_dict = %$ltc_dict;
	my %labelled_centroids;

	foreach my $cluster_index (keys %centroid_values){
		my $centroid_vector_index;
		my $min_cos_sim = 10;	# arbitrarily large value; (?)
		my @centroid = @{$centroid_values{$cluster_index}};
		foreach my $vector_index (@{$clustered_vectors{$cluster_index}}){
			my @vector = @{$ltc_vectors[$vector_index]};
			my $cos_sim = CosSim(\@centroid, \@vector);
			if ($cos_sim < $min_cos_sim){
				$min_cos_sim = $cos_sim;
				$centroid_vector_index = $vector_index;
			}
		}
		my $cui = $ltc_indices[$centroid_vector_index];
		my $term = $ltc_dict{$cui};
		$labelled_centroids{$cluster_index} = $term;
	}
	return \%labelled_centroids;
}

sub PrintResults {
# output format: cui \t term \t cluster name \n
	my %clustered_vectors = %$clustered_vectors;
	my %labelled_centroids = %$labelled_centroids;
	my %ltc_dict = %$ltc_dict;
	my @ltc_indices = @$ltc_indices;
	my $results_dir = "$base_dir/results";

	if (! -e $results_dir){
		mkdir $results_dir, 0755;		# owner can read/write, group members can read
	}

	my $results_file = $ltc_file;
	$results_file =~ s/.*?\/(.*)/$1/;

	open my $fh, '>>', "$results_dir/$results_file" or die "Can't open $results_dir/$results_file: $!";
	foreach my $cluster_index (%clustered_vectors){
		foreach my $vector_index (@{$clustered_vectors{$cluster_index}}){
			my $cluster_name = $labelled_centroids{$cluster_index};
			my $cui = $ltc_indices[$vector_index];
			my $term = $ltc_dict{$cui};
			print $fh "$cui\t$term\t$cluster_name\n";
		}
	}
	close $fh;
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

