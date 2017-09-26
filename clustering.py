#!/usr/bin/python
import sys
import os.path
import re
from collections import defaultdict

class LTCVectorConverter:

	def PrintUsageNotes(self):
		print "Usage: python vcluster_converter.py [ltc_file] [cui_vectors_file]"

	def GetPaths(self):
		#
		if len(sys.argv) < 2:
			self.PrintUsageNotes()
			sys.exit()
		else:
			self.ltc_file = sys.argv[1]
			self.cui_vectors_file = sys.argv[2]
		return self.ltc_file, self.cui_vectors_file

	def CheckPaths(self):
		# change to try/except pragma later
		# checks if filepaths 1. exists 2. are files
		# if not, exits
		error = None
		if not os.path.exists(self.ltc_file):
			print "\tError: " + self.ltc_file + " not found."
			error = True
		if not os.path.isfile(self.ltc_file):
			print "\tError: " + self.ltc_file + " is not a file."
			error = True
		if not os.path.exists(self.cui_vectors_file):
			print "\tError: " + self.cui_vectors_file + "not found."
			error = True
		if not os.path.isfile(self.cui_vectors_file):
			print "\tError: " + self.cui_vectors_file + "is not a file."
			error = True
		if error:
			self.PrintUsageNotes()
			sys.exit()

	def SaveLTCs(self):
		self.ltcs = defaultdict(dict)
		with open (self.ltc_file, 'r') as f:
			lines = f.readlines()
			for line in lines:
				matches = re.search(r'^\d+\t(\d+.\d+)\t(C\d{7})\t(.+)', line)
				if matches:
					score = matches.group(1)
					cui = matches.group(2)
					term = matches.group(3)
					self.ltcs[cui][term] = score
		return self.ltcs

	def SaveLTCVectors(self):
		self.ltc_vectors = []
		with open (self.cui_vectors_file, 'r') as f:
			lines = f.readlines()
			for line in lines:
				matches = re.search(r'^(C\d{7})(.+)', line)
				if matches:
					cui = matches.group(1)
					if cui in self.ltcs:
						vector_string = matches.group(2)
						vector = re.findall(r'(-?\d.\d+)', vector_string)
						self.ltc_vectors.append(vector)
		return self.ltc_vectors

	def PrintVectors(self):
		ltc_vector_file = self.cui_vectors_file + ".vcluster"
		num_rows = len(self.ltc_vectors)
		num_columns = len(self.ltc_vectors[0])
		matrix_size = str(num_rows) + ' ' + str(num_columns)
		with open(ltc_vector_file, 'w') as f:
			f.write(matrix_size)
			for vector in self.ltc_vectors:
				f.write(' '.join(vector))

def main():
	converter = LTCVectorConverter()
	converter.GetPaths()
	converter.CheckPaths()
	ltcs = converter.SaveLTCs()
	ltc_vectors = converter.SaveLTCVectors()
	converter.PrintVectors()

if __name__ == '__main__':
	main()



