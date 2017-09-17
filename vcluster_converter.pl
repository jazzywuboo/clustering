#!/usr/bin/perl
use strict;
use warnings;
use Cwd;
use Data::Dumper;
# usage: perl vcluster_converter.pl [unformatted_dir] [vcluster_dir] [num_clusters]

# takes in files containing cui-word2vec vectors and prints them in the format required for the vcluster program in CLUTO
# calls vcluster to perform clustering and matches cuis to vectors
# determines cluster centroid and labels cluster via the centroid

my ($unformatted_dir, $vcluster_dir, $num_clusters) = GetDirs();
my $input_filenames = SaveInputFilenames();
my $sizeof_matrices = GetSizeofMatrices();
my $matrices = ExtractMatrices();
#my $cui_vector_lookup = SaveCuiVectorPairs();

PrintVClusterMatrices($sizeof_matrices, $matrices);
#RunVCluster();
#MatchClusteredVectorsToCuis();

sub PrintUsageNotes {
	print "Usage:\tperl vcluster_converter.pl [unformatted_dir] [vcluster_dir] [num_clusters]\n";
}

sub GetDirs {
	# gets source directory and destination directory from user
	no warnings 'uninitialized';
	my $base_dir = cwd();
	my $unformatted_dir = $ARGV[0];
	my $vcluster_dir = $ARGV[1];
	my $num_clusters = $ARGV[2];
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
	if (! (-e $vcluster_dir)){
		mkdir "$base_dir/$vcluster_dir", 0755;
	}
	if ($num_clusters =~ /^-?\d+$/){
		if ($num_clusters < 0){
			print "Error: Number of clusters must be >= 1\n";
			PrintUsageNotes();	
			exit
		}
	}
	else {
		print "Error: Invalid input for number of clusters.\n";
		PrintUsageNotes();
		exit
	}
	$unformatted_dir = "$base_dir/$ARGV[0]";
	$vcluster_dir = "$base_dir/$ARGV[1]";
	return $unformatted_dir, $vcluster_dir, $num_clusters;
}

sub SaveInputFilenames {
	my @input_filenames;
	opendir my $dh, $unformatted_dir or die "Can't open $unformatted_dir: $!";
	while (my $file = readdir($dh)) {
		next if ($file =~ /^\./);
		next if -d $file;
		push @input_filenames, $file;
	}
	closedir $dh;
	return \@input_filenames;
}

sub GetSizeofMatrices {
	# determines size of matrix in each file
	my %sizeof_matrices;
	foreach my $file (@$input_filenames){
		open my $fh, '<', "$unformatted_dir/$file" or die "Can't open $unformatted_dir/$file: $!";
		while (my $line = <$fh>){
			if ($line =~ /^(-?\d+)\s(-?\d+)$/){
				my $num_columns = $1;
				my $num_rows = $2;
				if ($num_clusters >= $num_rows){
					print "Error: Number of clusters must be less than number of vectors ($file has $num_rows vector(s); you specified $num_clusters clusters).\n";
					PrintUsageNotes();
					exit
				}
				$sizeof_matrices{$file}{$num_rows} = $num_columns;
				last;
			}
		}
		close $fh;
	}
	return \%sizeof_matrices;
}

sub ExtractMatrices {
	# extractors word2vec matrices from each file
	my %matrices;
	foreach my $file (@$input_filenames){
		$matrices{$file} = ();
		open my $fh, '<', "$unformatted_dir/$file" or die "Can't open $unformatted_dir/$file: $!";
		while (my $line = <$fh>){
			if ($line =~ /^C\d{7}(.+)/){
				my $vector = $1;
				my @vector_vals = ($vector =~ /(-?\d.\d+)/g);
				push @{$matrices{$file}}, [@vector_vals];
			}
		}
		close $fh;
	}
	return \%matrices;
}

sub PrintVClusterMatrices {
	# prints dense matrices in format for vcluster program in CLUTO
	my ($sizeof_matrices, $matrices) = (@_);
	my %sizeof_matrices = %$sizeof_matrices;
	my %matrices = %$matrices;
	foreach my $file (keys %sizeof_matrices) {
		foreach my $num_rows (keys $sizeof_matrices{$file}){
			my $num_columns = $sizeof_matrices{$file}{$num_rows};
			open my $fh, ">", "$vcluster_dir/$file" or die "Can't open $vcluster_dir/$file: $!";
			print $fh "$num_rows $num_columns\n";
			foreach my $vector_vals (@{$matrices{$file}}) {
				print $fh join(' ', @$vector_vals);
				print $fh "\n";
			}
			close $fh;
		}
	}
	print "Vcluster-formatted files located at: $vcluster_dir\n";
}

sub SaveCuiVectorPairs {
	my %cui_vector_lookup;
	foreach my $file (@$input_filenames){
		open my $fh, '<', "$unformatted_dir/$file" or die "Can't open $unformatted_dir/$file: $!";
		while (my $line = <$fh>){
			if ($line =~ /^(C\d{7})(.+)/){
				my $cui = $1;
				$cui_vector_lookup{$file}{$cui} = ();
				my $vector = $2;
				my @vector_vals = ($vector =~ /(-?\d.\d+)/g);
				push @{$cui_vector_lookup{$file}{$cui}}, [@vector_vals];
			}
		}
		close $fh;
	}
	return \%cui_vector_lookup;
}

sub RunVCluster {
	#my $vcluster_command = `./vcluster $vcluster_dir/file $num_clusters`;
}

sub MatchClusteredVectorsToCuis {
	#my %cui_vector_lookup = %$cui_vector_lookup;
}

