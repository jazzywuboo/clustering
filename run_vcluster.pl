#!/usr/bin/perl
use strict;
use warnings;
use Cwd;

# usage: perl run_vcluster.pl [vcluster_path] [reduced_vector_file] [num_clusters]
# eg. perl run_Vcluster.pl cluto-2.1.2/Darwin-i386 somArg/1960_1989_window8 20

my ($base_dir, $vcluster_path, $reduced_vector_file, $num_clusters) = GetArgs();
RunVCluster();

sub GetArgs {
	# gets source directory and destination directory from user
	no warnings 'uninitialized';
	my $base_dir = 			cwd();
	my $vcluster_path = 	"$base_dir/$ARGV[0]";
	my $reduced_vector_file = 		$ARGV[1];
	my $num_clusters = 		$ARGV[2];
	my $opt_data_dir = 		$ARGV[3];

	if (-e $opt_data_dir){
		$reduced_vector_file = 		"$opt_data_dir/$reduced_vector_file";
		$opt_data_dir = 			"$opt_data_dir/$opt_data_dir";
	}

	if ($#ARGV < 3 || $#ARGV > 4){
		print "Error: 3 arguments required; 4th is optional\n";
		print "Usage: perl run_vcluster.pl [vcluster_path] [reduced_vector_file] [num_clusters] [opt_data_dir]\n";
		exit
	}

	elsif (! -e "$vcluster_path/vcluster" || ! -e $reduced_vector_file || ! -f $reduced_vector_file || $num_clusters < 0 || !($num_clusters =~ /(^-?\d+$)/)){
		if (! -e "$vcluster_path/vcluster"){	# check if vcluster program exists in directory
			print "Error: Path to vcluster does not exist.\n";
		}
		if (! -e $reduced_vector_file){
			print "Error: Input file $reduced_vector_file not found.\n";
		}
		if (! -f $reduced_vector_file){
			print "Error: Invalid input for number of clusters. Must be an integer > 0.\n";
		}
		if ($num_clusters < 0 || ! ($num_clusters =~ /(^-?\d+$)/)){
			print "Error: Number of clusters must be an integer greater than 0.\n";
		}
		print "Usage: perl run_vcluster.pl [vcluster_path] [reduced_vector_file] [num_clusters]\n";
		exit
	}
	return $base_dir, $vcluster_path, $reduced_vector_file, $num_clusters;
}

sub RunVCluster {
	chdir $vcluster_path;
	$reduced_vector_file = "$base_dir/$reduced_vector_file";
	my $vcluster_command = "./vcluster $reduced_vector_file $num_clusters";
	system($vcluster_command);
	chdir;
}
