#!/usr/bin/perl
use strict;
use warnings;
use Cwd;

# usage: perl run_vcluster.pl [vcluster_path] [input_file] [num_clusters]
# eg. perl run_Vcluster.pl cluto-2.1.2/Darwin-i386 somArg/1960_1989_window8 20

my ($base_dir, $vcluster_path, $input_file, $num_clusters) = GetArgs();
RunVCluster();

sub GetArgs {
	# gets source directory and destination directory from user
	no warnings 'uninitialized';
	my $base_dir = cwd();
	my $vcluster_path = $ARGV[0];
	my $input_file = "$base_dir/$ARGV[1]";
	my $num_clusters = $ARGV[2];

	if ($#ARGV < 2 || $#ARGV > 2){
		print "Error: 3 arguments required.\n";
		print "Usage: perl run_vcluster.pl [vcluster_path] [input_file] [num_clusters]\n";
		exit
	}
	elsif (! -e "$vcluster_path/vcluster" || ! -e $input_file || ! -f $input_file || $num_clusters < 0 || !($num_clusters =~ /(^-?\d+$)/)){
		if (! -e "$vcluster_path/vcluster"){	# check if vcluster program exists in directory
			print "Error: Path to vcluster does not exist.\n";
		}
		if (! -e $input_file){
			print "Error: Input file $input_file not found.\n";
		}
		if (! -f $input_file){
			print "Error: Invalid input for number of clusters. Must be an integer > 0.\n";
		}
		if ($num_clusters < 0 || ! ($num_clusters =~ /(^-?\d+$)/)){
			print "Error: Number of clusters must be an integer greater than 0.\n";
		}
		print "Usage: perl run_vcluster.pl [vcluster_path] [input_file] [num_clusters]\n";
		exit
	}
	return $base_dir, $vcluster_path, $input_file, $num_clusters;
}

sub RunVCluster {
	my $vcluster_dir = "$base_dir/$vcluster_path";
	chdir $vcluster_dir;
	my $vcluster_command = "./vcluster $input_file $num_clusters";
	system($vcluster_command);
	chdir;
}


