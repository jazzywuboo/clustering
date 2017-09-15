#!/usr/bin/perl
use strict;
use warnings;
use Cwd;
use Data::Dumper;

my $dir = cwd();
my ($file_path, $file_name) = GetARGV();
my ($num_rows, $num_columns) = DetermineMatrixSize();
my $matrix = ExtractMatrix();												# grab vectors from source files
PrintMatrixFile($num_rows, $num_columns, $matrix);		# convert file to format required by CLUTO													# run cluto on converted file						

sub GetARGV {
	no warnings 'uninitialized';
	my $file_name = $ARGV[0];
	my $file_path = "$dir/vector_files/$file_name";					# get location of source file from user input
	if (! (-e $file_path) ){
		print "$file_path: File not found.\n";
		exit;
	}
	else {
		$file_path =~ s/\s+//;											# remove any excess whitespace
	}
	return $file_path, $file_name;
}

sub DetermineMatrixSize {
	#extracts matrix info
	my $num_columns;
	if ($file_name =~ /.*?cui.(\d+)/) {
		$num_columns = $1;
	}
	my $num_rows;
	open my $fh, '<', "$file_path" or die "Can't open $file_path: $!";
	while (my $line = <$fh>){
		if ($line =~ /^C\d{7}(.+)/){
			$num_rows++;
		}
	}
	close $fh;
	return $num_rows, $num_columns;
}

sub ExtractMatrix {
	#extracts feature vectors (matrix) for linking cuis
	my %matrices;
	open my $fh, '<', "$file_path" or die "Can't open $file_path: $!";
	while (my $line = <$fh>){
		if ($line =~ /^(C\d{7})(.+)/){
			my $cui = $1;
			my $vector = $2;
			my @scores = ($vector =~ /(-?\d.\d+)/g);
			$matrices{$cui} = [@scores];
		}
	}
	close $fh;
	if (! %matrices){
		print "File contains no vector data to cluster.\n";
		exit;
	}
	print Dumper(\%matrices);
	return \%matrices;
}

sub PrintMatrixFile {
	#prints vectors in dense matrix format required by matrix 
	my ($num_rows, $num_columns, $matrix) = (@_);
	$file_path =~ s/vector_files/vcluster_files/;
	open my $fh, '>', "$file_path" or die "Can't open $file_path: $!";
	print $fh "$num_rows $num_columns\n";
	foreach my $cui (keys %$matrix){
		foreach my $score_array (@{$matrix->{$cui}}) {
			print $fh "$score_array ";	
		}
		print $fh "\n";
	}
	close $fh;
	print "Finished printing to: $file_path\n";
}


