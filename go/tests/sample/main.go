package main

import "fmt"

var version = "dev"

func main() {
	fmt.Println("testapp version:", version)
}

func add(a, b int) int {
	return a + b
}
