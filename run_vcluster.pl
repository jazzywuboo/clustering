#!/usr/bin/perl
use strict;
use warnings;
use Cwd;

# usage: perl run_vcluster.pl [source_dir] [num_clusters]

my ($input_file, $num_clusters, $base_dir) = GetArgs();
#RunVCluster();

sub GetArgs {
	# gets source directory and destination directory from user
	no warnings 'uninitialized';
	my $base_dir = cwd();
	my $input_file = $ARGV[0];
	my $num_clusters = $ARGV[1];

	if (! -e $input_file || ! -f $input_file || $num_clusters < 0 || !($num_clusters =~ /(^-?\d+$)/)){
		if (! -e $input_file){
			print "Error: Input file $input_file not found.\n";
		}
		if (! -f $input_file){
			print "Error: Invalid input for number of clusters. Must be an integer > 0.\n";
		}
		if ($num_clusters < 0){
			print ""
		}
		if (! ($num_clusters =~ /(^-?\d+$)/)){
			print "Error: Number of clusters must be an integer.\n";
		}
		print "Usage: perl run_vcluster.pl [source_dir] [num_clusters]\n";
		exit
	}
	return $input_file, $num_clusters, $base_dir;
}

sub RunVCluster {
	my $vcluster_dir = "$base_dir/cluto-2.1.1/Linux";
	chdir $vcluster_dir;
	my $vcluster_command = "./vcluster $input_file $num_clusters";
	system($vcluster_command);
	chdir;
}
