#!/usr/bin/perl
use strict;
use warnings;
use Cwd;

my $start_time = time;

my $ltc_file = $ARGV[0];
my $vector_file = $ARGV[1];
my $num_clusters = $ARGV[2];
my $vcluster_path = $ARGV[3];
my $opt_data_dir = $ARGV[4];

if ($#ARGV < 4 || $#ARGV > 5) {
	print "Program requires 3 arguments to run; 4th is optional.\n";
	print "Usage: perl run_clustering.pl [ltc_file] [vector_file] [num_clusters] [vcluster_path] [opt_data_dir]\n";
	exit
}

my $reduced_ltc_file = $ltc_file . '_reduced';
my $reduced_vector_file = $vector_file . '_v';
my $clustered_file = $reduced_vector_file . '.clustering.' . $num_clusters;

for (my $i = 0; $i <= 20; $i += 0.05){
	`perl vcluster_converter.pl $ltc_file $vector_file $opt_data_dir`;
	`perl run_vcluster.pl $vcluster_path $reduced_vector_file $num_clusters $opt_data_dir`;
	`perl label_and_rank_clusters.pl $reduced_ltc_file $reduced_vector_file $clustered_file $opt_data_dir`;
}
my $end_time = time - $start_time;
my $execution_time = $end_time/60;
printf("Execution time: %.2f mins\n", $execution_time);
