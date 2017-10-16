#!/usr/bin/perl
use strict;
use warnings;
use Cwd;
use Data::Dumper;

my $start_time = time;
my ($base_dir, $reduced_ltc_file, $reduced_vector_file, $clustered_file, $num_clusters) = GetArgs();
my ($scores, $cuis, $cui_terms) = ExtractLTCInfo();
my $vectors = ExtractVectors();
my $clustered_vectors = ExtractClusteredVectors();
my $cluster_rankings = CalculateInterClusterRanking();
my $centroid_values = CalculateCentroids();
my $cluster_names = LabelClusters();
PrintRankedTerms();
PrintExecutionTime();

sub PrintExecutionTime {
	my $execution_time = (time - $start_time)/60;
	printf("Execution time: %.2f minutes\n", $execution_time);
}

sub PrintUsageNotes {
	print "Usage: perl label_clusters.pl [reduced_ltc_file] [reduced_vector_file] [clustered_file]\n";
}

sub GetArgs {
	# gets source directory and destination directory from user
	no warnings 'uninitialized';
	my $base_dir = cwd();
	my $reduced_ltc_file = $ARGV[0];
	my $reduced_vector_file = $ARGV[1];
	my $clustered_file = $ARGV[2];

	if ($#ARGV < 2 || $#ARGV > 2){
		print "Program takes 3 arguments.\n";
		PrintUsageNotes();
		exit
	}
	if (! -e $reduced_ltc_file || ! -f $reduced_ltc_file || ! -e $reduced_vector_file || ! -f $reduced_vector_file || ! -e $clustered_file || ! -f $clustered_file){
		if (! -e $reduced_ltc_file){
			print "Error: $reduced_ltc_file not found.\n";
		}
		if (! -f $reduced_ltc_file){
			print "Error: $reduced_ltc_file must be a file.\n";
		}
		if (! -e $reduced_vector_file){
			print "Error: $reduced_vector_file not found.\n";
		}
		if (! -f $reduced_vector_file){
			print "Error: $reduced_vector_file must be a file.\n";
		}
		if (! -e $clustered_file){
			print "Error: $clustered_file not found.\n";
		}
		if (! -f $clustered_file){
			print "Error: $clustered_file must be a file.\n";
		}
		PrintUsageNotes();
		exit
	}
	my $num_clusters;
	if ($clustered_file =~ /.*clustering\.(\d+)/){
		$num_clusters = $1;
	}

	return $base_dir, $reduced_ltc_file, $reduced_vector_file, $clustered_file, $num_clusters;
}

sub ExtractLTCInfo {
	my @scores;
	my @cuis;
	my %cui_terms;
	open my $fh, '<', "$base_dir/$reduced_ltc_file" or die "Can't open $base_dir/$reduced_ltc_file: $!";
	while (my $line = <$fh>) {
		if ($line =~ /^(\d+.\d+)\t(C\d{7})\t(.+)/){
			my $score = $1;
			my $cui = $2;
			my $term = $3;
			push @scores, $score;
			push @cuis, $cui;
			$cui_terms{$cui} = $term;
		}
	}
	close $fh;
	return \@scores, \@cuis, \%cui_terms;
}

sub ExtractVectors {
	my @vectors;
	open my $fh, '<', "$base_dir/$reduced_vector_file" or die "Can't open $base_dir/$reduced_vector_file: $!";
	my $line_num = 0;
	while (my $line = <$fh>) {
		if ($line_num > 0){
			my @vector = split (' ', $line);
			push @vectors, [@vector];
		}
		$line_num++;
	}
	close $fh;
	return \@vectors;
}

sub ExtractClusteredVectors {
	my @clustered_vectors;
	open my $fh, '<', "$base_dir/$clustered_file" or die "Can't open $base_dir/$clustered_file: $!";
	my $vector_index = 0;
	while (my $line = <$fh>){
		my $cluster_index = $line;
		$cluster_index =~ s/\s+//;
		push @{$clustered_vectors[$cluster_index]}, $vector_index;
		$vector_index++;
	}
	close $fh;
	return \@clustered_vectors;
}

sub CalculateInterClusterRanking {
	my @clustered_vectors = @$clustered_vectors;
	my @scores = @$scores;
	my %temp_cluster_rankings;
	my @cluster_rankings;
	foreach my $cluster_index (0 .. $#clustered_vectors){
		my $cluster_score = 0;
		my $vector_indices = $clustered_vectors[$cluster_index];
		foreach my $vector_index (@$vector_indices) {
			my $score = $scores[$vector_index];
			$cluster_score += $score;
		}
		$temp_cluster_rankings{$cluster_index} = $cluster_score;
	}
	my @cluster_indices = sort {$temp_cluster_rankings{$b} <=> $temp_cluster_rankings{$a}} keys(%temp_cluster_rankings);	# sorts cuis by score
	foreach my $cluster_index (@cluster_indices){
		push @cluster_rankings, $cluster_index;
	}
	return \@cluster_rankings;
}

sub CalculateCentroids {
	# calculates the "centroid" (average value of all vectors) for a cluster
	my @clustered_vectors = @$clustered_vectors;
	my @vectors = @$vectors;
	my $num_vectors = $#vectors;
	my $num_columns = @{$vectors[0]};
	my %centroid_values;
	foreach my $cluster_index (0 .. $#clustered_vectors){
		my $vectors_per_cluster = 0;										# counter for vectors per cluster
		$centroid_values{$cluster_index} = [(0) x $num_columns];			# initialize centroid values to 0
		foreach my $vector_index (@{$clustered_vectors[$cluster_index]}){	# for each vector
			$vectors_per_cluster++;											# increment vectors per cluster
			my @vector = @{$vectors[$vector_index]};						# get vector from vectors
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

sub LabelClusters {
	# labels cluster centroid with vector closest to the centroid, determined with cosine similarity 
	my %centroid_values = %$centroid_values;
	my %cui_terms = %$cui_terms;
	my @vectors = @$vectors;
	my @clustered_vectors = @$clustered_vectors;
	my @cuis = @$cuis;
	my %cluster_names;

	foreach my $cluster_index (keys %centroid_values){
		my $centroid_vector_index;
		my $min_cos_sim = 10;	# arbitrarily large value (?)
		my @centroid = @{$centroid_values{$cluster_index}};
		foreach my $vector_index (@{$clustered_vectors[$cluster_index]}){
			my @vector = @{$vectors[$vector_index]};
			my $cos_sim = CosSim(\@centroid, \@vector);
			if ($cos_sim < $min_cos_sim){
				$min_cos_sim = $cos_sim;
				$centroid_vector_index = $vector_index;
			}
		}
		my $cui = $cuis[$centroid_vector_index];
		my $term = $cui_terms{$cui};
		$cluster_names{$cluster_index} = $term;
	}
	return \%cluster_names;
}

sub PrintRankedTerms {
	my @cluster_rankings = @$cluster_rankings;
	my @clustered_vectors = @$clustered_vectors;
	my @scores = @$scores;
	my @cuis = @$cuis;
	my %cluster_names = %$cluster_names;
	my %cui_terms = %$cui_terms;
	my $results_dir = "$base_dir/results";

	if (! -e $results_dir){
		mkdir $results_dir, 0755;		# owner can read/write, group members can read
	}

	my $results_file = $reduced_ltc_file;
	$results_file =~ s/.*\/(.*)/$1/;
	$results_file =~ s/(.*?_)(.*)/$1results/;

	open my $fh, '>', "$results_dir/$results_file" or die "Can't open $results_dir/$results_file: $!";
	foreach my $cluster_index (@cluster_rankings){
		my $cluster_name = $cluster_names{$cluster_index};
		foreach my $vector_index (@{$clustered_vectors[$cluster_index]}){
			my $score = $scores[$vector_index];
			my $cui = $cuis[$vector_index];
			my $term = $cui_terms{$cui};
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
