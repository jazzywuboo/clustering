#!/usr/bin/perl
use strict;
use warnings;
use Cwd;

my ($source_dir, $dest_dir) = GetDirs();
my $sizeof_matrices = DetermineSizeofMatrices();
my $matrices = ExtractMatrices();
PrintVClusterMatrices($sizeof_matrices, $matrices);

sub GetDirs {
	# gets source directory and destination directory from user
	no warnings 'uninitialized';
	my $base_dir = cwd();
	my $source_dir = "$ARGV[0]";
	my $dest_dir = "$ARGV[1]";
	if (! (-e $source_dir) ){
		print "$source_dir not found. Check source directory name.\n";
		exit
	}
	if (! (-e $dest_dir)){
		mkdir "$base_dir/$dest_dir", 0755;
	}
	$source_dir = "$base_dir/$ARGV[0]";
	$dest_dir = "$base_dir/$ARGV[1]";
	return $source_dir, $dest_dir;
}

sub DetermineSizeofMatrices {
	# determines size of matrix in each file
	my %sizeof_matrices;
	opendir my $dh, $source_dir or die "Can't open $source_dir: $!";
	while (my $file = readdir($dh)) {
		next if ($file =~ /^\./);
		next if -d $file;
		if ($file =~ /.*?.cui.(\d+)/){
			my $num_rows = $1;
			my $num_columns;
			open my $fh, '<', "$source_dir/$file" or die "Can't open $source_dir/$file: $!";
			while (my $line = <$fh>){
				if ($line =~ /^C\d{7}(.+)/){
					$num_columns++;
				}
			}
			close $fh;
			$sizeof_matrices{$file}{$num_rows} = $num_columns;
		}
	}
	closedir $dh;
	return \%sizeof_matrices;
}

sub ExtractMatrices {
	# extractors word2vec matrices from each file
	my %matrices;
	opendir my $dh, $source_dir or die "Can't open $source_dir: $!";
	while (my $file = readdir($dh)) {
		next if ($file =~ /^\./);
		next if -d $file;
		open my $fh, '<', "$source_dir/$file" or die "Can't open $source_dir/$file: $!";
			$matrices{$file} = ();
			while (my $line = <$fh>){
				if ($line =~ /^C\d{7}(.+)/){
					my $vector = $1;
					my @vector_vals = ($vector =~ /(-?\d.\d+)/g);
					push @{$matrices{$file}}, [@vector_vals];
				}
			}
		close $fh;
	}
	closedir $dh;
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
			open my $fh, ">", "$dest_dir/$file" or die "Can't open $dest_dir/$file: $!";
			print $fh "$num_rows $num_columns\n";
			foreach my $vector_vals (@{$matrices{$file}}) {
				print $fh join(' ', @$vector_vals);
				print $fh "\n";
			}
			close $fh;
		}
	}
	print "Vcluster-formatted files located at: $dest_dir\n";
}

