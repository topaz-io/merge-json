package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"os"

	"dario.cat/mergo"
)

func main() {
	fmt.Printf("merge-json\n")

	output := flag.String("output", "", "output filename")

	flag.Parse()

	if err := merge(flag.Args(), *output); err != nil {
		fmt.Printf("error: %s\n", err.Error())
		os.Exit(1)
	}

	fmt.Println()

	os.Exit(0)
}

func merge(files []string, outfile string) error {
	var (
		src map[string]any
		dst = make(map[string]any)
		err error
	)

	if len(files) == 1 {
		r, err := os.Open(files[0])
		if err != nil {
			return err
		}
		defer r.Close()

		w, err := os.Create(outfile)
		if err != nil {
			return err
		}
		defer w.Close()

		if _, err := io.Copy(w, r); err != nil {
			return err
		}

		return nil
	}

	for _, file := range files {
		fmt.Printf("<= %s\n", file)

		src, err = loadFile(file)
		if err != nil {
			return err
		}

		if err := mergo.Merge(&dst, src); err != nil {
			return err
		}
	}

	w, err := os.Create(outfile)
	if err != nil {
		return err
	}
	defer w.Close()

	enc := json.NewEncoder(w)
	enc.SetIndent("", "  ")
	enc.SetEscapeHTML(true)

	fmt.Printf("=> %s\n", outfile)

	if err := enc.Encode(dst); err != nil {
		return err
	}

	return nil
}

func loadFile(filePath string) (map[string]any, error) {
	f, err := os.Open(filePath)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	var data map[string]any

	dec := json.NewDecoder(f)

	if err := dec.Decode(&data); err != nil {
		return nil, err
	}

	return data, nil
}
