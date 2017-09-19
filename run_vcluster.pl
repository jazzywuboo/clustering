#!/usr/bin/perl
use strict;
use warnings;
use Cwd;

# usage: perl run_vcluster.pl [source_dir] [num_clusters] 

my $base_dir = cwd();
my ($input_dir, $num_clusters) = GetArgs();
my $input_filenames = SaveInputFilenames();
RunVCluster();

sub GetArgs {
	# gets source directory and destination directory from user
	no warnings 'uninitialized';;
	my $input_dir = $ARGV[0];
	my $num_clusters = $ARGV[1];

	if (-f $input_dir){
		print "Error: Input must be a directory.\n";
		exit
	}
	if (! (-e $input_dir) ){
		print "Error: $input_dir not found. Check source directory name.\n";
		exit
	}
	if ($num_clusters =~ /(^-?\d+$)/){
		if ($num_clusters < 0){
			print "Error: Invalid input for number of clusters. Must be an integer > 0.\n";
			exit
		}
	}
	else {
		print "Error: Invalid input for number of clusters. Must be an integer > 0.\n";
		exit
	}
	my $input_dir = "$base_dir/$input_dir";
	return $input_dir, $num_clusters;
}

sub SaveInputFilenames {
	my @input_filenames;
	opendir my $dh, $input_dir or die "Can't open $input_dir: $!";
	while (my $file = readdir($dh)) {
		next if ($file =~ /^\./);
		next if -d $file;
		next if ($file =~ /\.clustering\./);
		push @input_filenames, $file;
	}
	closedir $dh;

	return \@input_filenames;
}

sub RunVCluster {
	my $vcluster_dir = "$base_dir/cluto-2.1.1/Linux";
	chdir $vcluster_dir;
	foreach my $file (@$input_filenames){
		my $vcluster_command = "./vcluster $vcluster_dir/$file $num_clusters";
		system($vcluster_command);
	}
	chdir;
}


