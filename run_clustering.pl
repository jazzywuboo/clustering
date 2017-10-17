#!/usr/bin/perl
use strict;
use warnings;

my $start_time = time;

my $ltc_file = $ARGV[0];
my $vector_file = $ARGV[1];
my $vcluster_path = $ARGV[2];
my $opt_data_dir = $ARGV[3];

if ($#ARGV < 3 || $#ARGV > 4) {
	print "Program requires 2 arguments to run; 3rd is optional.\n";
	print "Usage: perl run_clustering.pl [ltc_file] [vector_file] [vcluster_path] [opt_data_dir]\n";
	exit
}

my $reduced_ltc_file = $ltc_file . '_reduced';
my $reduced_vector_file = $vector_file . '_v';

for (my $num_clusters = 0; $num_clusters <= 1; $num_clusters += 0.05){
	`perl vcluster_converter.pl $ltc_file $vector_file $opt_data_dir`;
	`perl run_vcluster.pl $vcluster_path $reduced_vector_file $num_clusters $opt_data_dir`;
	my $clustered_file = $reduced_vector_file . '.clustering.' . $num_clusters;
	`perl label_and_rank_clusters.pl $reduced_ltc_file $reduced_vector_file $clustered_file $opt_data_dir`;
}
my $end_time = time - $start_time;
my $execution_time = $end_time/60;
printf("Execution time: %.2f mins\n", $execution_time);
