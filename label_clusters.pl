#!/usr/bin/perl
use strict;
use warnings;
use Cwd;
use Data::Dumper;

## Main
my $start_time = time;

my ($cui_terms_dir, $unformatted_dir, $formatted_dir, $clustered_dir) = GetArgs();
#my $cui_terms = ExtractCuiTerms();					# file -> cui -> term
#my $cui_vector_indices = ExtractCuiVectorIndices();	# file -> vector_index -> cui
my $vector_indices = ExtractVectorIndeces();		# file -> vector_index -> @vector_value
my $cluster_indices = ExtractClusterIndices();		# file -> cluster_index -> @vector_indices
my $centroid_values = CalculateCentroids();		# file -> cluster_index -> @centroid
#my $centroid_cuis = LabelCentroidCuis();			# file -> cluster_index -> centroid_cui
#my $labelled_clusters = LabelClusters();			# file -> centroid_cui -> @vector_cuis
#PrintLabelledClusters();							# file format:
						# cluster_index -> centroid_cui -> centroid_term -> vector_cui -> vector_term

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

sub ExtractCuiTerms {
	my %cui_terms;
	opendir my $dh, $unformatted_dir or die "Can't open $unformatted_dir: $!";
	while (my $file = readdir($dh)) {
		next if ($file =~ /^\./);
		next if -d $file;
		open my $fh, "$unformatted_dir/$file" or die "Can't open $unformatted_dir/$file: $!";
		close $fh;
	}
	closedir $dh;
	return \%cui_terms;
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
				push @{$vector_indices{$file}{$vector_index}}, [@vector_vals];
			}
			$vector_index++;
		}
		close $fh;
	}
	closedir $dh;
	return \%vector_indices;
}

sub ExtractClusterIndices {
	# extracts results of clustering
	# tells us which cluster a vector belongs to
	# returns a hash of $cluster_indices{$file}{$cluster_index} = @vector_index
	my %cluster_indices;
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
			push @{$cluster_indices{$file}{$cluster_index}}, $vector_index;
			$vector_index++;
		}
		close $fh;	
	}
	closedir $dh;
	return \%cluster_indices;
}

sub CalculateCentroids {
	my %cluster_indices = %$cluster_indices;
	my %vector_indices = %$vector_indices;
	my %centroid_values;
	foreach my $file (keys %cluster_indices){						# for each file
		foreach my $cluster_index (keys $cluster_indices{$file}){	# for each cluster
			my @vector_index_array = @{$cluster_indices{$file}{$cluster_index}};
			my $vectors_per_cluster = $#vector_index_array;
			my $vector_count = 0;
			foreach my $vector_index (@vector_index_array){			# for each array of vectors within the cluser
				my @vector_vals = $vector_indices{$file}{$vector_index};
				foreach my $v_i (@vector_vals){
					if($vector_count == 0){
						push @{$centroid_values{$cluster_index}}, $v_i;
					}
					else {
						$centroid_values{$cluster_index}[$vector_count] += $v_i;
					}
				}
				$vector_count++;
			}
		}
	}
	return \%centroid_values;
}



