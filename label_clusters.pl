#!/usr/bin/perl
use strict;
use warnings;
use Cwd;
use Data::Dumper;

## Main
my $start_time = time;

my ($unformatted_dir, $clustered_dir) = GetArgs();
my $vector_indeces = ExtractVectorIndeces();
my $clustered_vector_indices = ExtractClusteredVectors();
my $clustered_vectors = ConvertIndicesToVectors();
my $cluster_centroids = CalculateCentroid();
PrintExecutionTime();

sub PrintExecutionTime {
	my $execution_time = (time - $start_time)/60;
	printf("Execution time: %.2f minutes\n", $execution_time);
}

sub PrintUsageNotes {
	print "Usage: perl label_clusters.pl [unformatted_dir] [clustered_dir]";
}

sub GetArgs {
	# gets source directory and destination directory from user
	no warnings 'uninitialized';
	my $base_dir = cwd();
	my $unformatted_dir = $ARGV[0];
	my $clustered_dir = $ARGV[1];

	if (-f $unformatted_dir){
		print "Error: Input must be a directory.\n";
		PrintUsageNotes();
		exit
	}
	if (! (-e $unformatted_dir) ){
		print "Error: $unformatted_dir not found. Check source directory name.\n";
		PrintUsageNotes();
		exit
	}
	$unformatted_dir = "$base_dir/$unformatted_dir";
	$clustered_dir = "$base_dir/$clustered_dir";
	return $unformatted_dir, $clustered_dir;
}

sub ExtractVectorIndeces {
	my %vector_indeces;
	my $vector_index = 0;
	opendir my $dh, $unformatted_dir or die "Can't open $unformatted_dir: $!";
	while (my $file = readdir($dh)) {
		next if ($file =~ /^\./);
		next if -d $file;
		open my $fh, "$unformatted_dir/$file" or die "Can't open $unformatted_dir/$file: $!";
		while (my $line = <$fh>) {
			if ($line =~ /^(C\d{7})(.+)/){
				$vector_index++;
				my $cui = $1;
				my $vector = $2;
				$vector_indeces{$file}{$vector_index} = $vector;
			}
		}
		close $fh;
	}
	closedir $dh;
	return \%vector_indeces;
}

sub ExtractClusteredVectors {
	my %clustered_vector_indices;
	my $vector_index = 0;
	opendir my $dh, $clustered_dir or die "Can't open $clustered_dir: $!";
	while (my $file = readdir($dh)) {
		next if ($file =~ /^\./);
		next if -d $file;
		open my $fh, "$clustered_dir/$file" or die "Can't open: $clustered_dir/$file: $!";
		while (my $line = <$fh>){
			if ($line =~ /(^\d+$)/) {
				$vector_index++;
				my $cluster_index = $1+1;
				$file =~ s/.clustering.\d+//;	# remove ".clustering.$num_clusters" from filename
				push @{$clustered_vector_indices{$file}{$cluster_index}}, $vector_index;
			}
		}
		close $fh;
	}
	closedir $dh;
	return \%clustered_vector_indices;
}

sub ConvertIndicesToVectors {
	#my @vector_vals = ($vector =~ /(-?\d.\d+)/g);
	my %clustered_vector_indices = %$clustered_vector_indices;
	my %vector_indeces = %$vector_indeces;
	my %clustered_vectors;

	foreach my $file (sort keys %clustered_vector_indices){
		foreach my $cluster_index (sort {$a <=> $b} keys $clustered_vector_indices{$file}){
			foreach my $vector_index (@{$clustered_vector_indices{$file}{$cluster_index}}){
				if (exists $vector_indeces{$file}{$vector_index}){
					my $vector = $vector_indeces{$file}{$vector_index};
					my @vector_vals = ($vector =~ /(-?\d.\d+)/g);
					push @{$clustered_vectors{$file}{$cluster_index}}, [@vector_vals];
				}
			}
		}
	}
	return \%clustered_vectors;
}

sub CalculateCentroid {
	my %clustered_vectors = %$clustered_vectors;
	my %cluster_centroid;
	my %vectors_per_cluster;

	foreach my $file (keys %clustered_vectors){
		foreach my $cluster_index (keys $clustered_vectors{$file}){
			foreach my $vector (@{$clustered_vectors{$file}{$cluster_index}}) {
				my $i = 0;
				foreach my $v_i (@$vector){
					$cluster_centroid{$file}{$cluster_index}[$i] += $v_i;
					$i++;
				}
				$vectors_per_cluster{$file}{$cluster_index} = $i;
			}
		}
	}
	foreach my $file (keys %cluster_centroid){
		foreach my $cluster_index (keys $cluster_centroid{$file}){
			foreach my $avg (@{$cluster_centroid{$file}{$cluster_index}}){
				my $vectors_per_cluster = $vectors_per_cluster{$file}{$cluster_index};
				$avg /= $vectors_per_cluster;
			}
		}
	}
	return \%cluster_centroids;
}

sub LabelCentroid {
	my $cluster_centroids = %$cluster_centroids;
	my $clustered_vectors = %$clustered_vectors;
	
}







