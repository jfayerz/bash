#!/bin/bash

# problem One
# Write three functions that compute the sum
# of the numbers in a given list
# using a for-loop, a while-loop, and recursion.

declare -a arr=(1 2 3 4 5)

#declare -a arr=($1 $2 $3 $4 $5)

#### forLoop Function ####

forLoop(){
	((i=0))

		for f in "${arr[@]}"
	do
		i=$(($i + $f))
	done

	echo "$i"
	}

#### While Loop Function ####

whileLoop(){
	((i=0))
	((x=0))
		while [ $x -le ${#arr[@]} ] 
	do
	
		i=$(($i + arr[$x]))
		((x++))
	done

	echo "$i" 
	}

whileLoop

forLoop
