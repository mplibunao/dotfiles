package main

import (
	"bytes"
	"flag"
	"fmt"
	"os"
	"path/filepath"
)

func linkSettings(source, live string, checkOnly bool) error {
	source, err := filepath.EvalSymlinks(source)
	if err != nil {
		return fmt.Errorf("read repo settings: %w", err)
	}
	info, err := os.Lstat(live)
	if os.IsNotExist(err) {
		return fmt.Errorf("enable Settings File in TinyCast Settings → Backup first")
	}
	if err != nil {
		return err
	}
	if info.Mode()&os.ModeSymlink != 0 {
		target, err := filepath.EvalSymlinks(live)
		if err == nil && target == source {
			fmt.Printf("Already linked: %s\n", live)
			return nil
		}
		return fmt.Errorf("refusing to replace another symlink: %s", live)
	}
	if checkOnly {
		return fmt.Errorf("settings are not linked to this checkout: %s", live)
	}
	if !info.Mode().IsRegular() {
		return fmt.Errorf("settings path is not a regular file: %s", live)
	}
	expected, err := os.ReadFile(source)
	if err != nil {
		return err
	}
	current, err := os.ReadFile(live)
	if err != nil {
		return err
	}
	if !bytes.Equal(current, expected) {
		return fmt.Errorf("local settings differ from the repo; review and copy them first")
	}
	backupDir, err := os.MkdirTemp(filepath.Dir(live), "settings-backup-")
	if err != nil {
		return err
	}
	backup := filepath.Join(backupDir, filepath.Base(live))
	if err := os.WriteFile(backup, current, info.Mode().Perm()); err != nil {
		return err
	}
	pending := filepath.Join(backupDir, "link")
	if err := os.Symlink(source, pending); err != nil {
		return err
	}
	// Quitting TinyCast prevents writes after this check; the backup stays for recovery.
	saved, err := os.ReadFile(backup)
	if err != nil {
		return err
	}
	current, err = os.ReadFile(live)
	if err != nil {
		return err
	}
	if !bytes.Equal(saved, expected) || !bytes.Equal(current, expected) {
		return fmt.Errorf("settings changed during backup; kept backup at %s", backup)
	}
	if err := os.Rename(pending, live); err != nil {
		return err
	}
	fmt.Printf("Linked: %s → %s\nBackup: %s\n", live, source, backup)
	return nil
}

func run() error {
	checkOnly := flag.Bool("check", false, "Verify the settings link without changing files")
	flag.Parse()
	if flag.NArg() != 0 {
		return fmt.Errorf("run from the dotfiles root: go run nix/scripts/tinycast-link-settings.go [--check]")
	}
	repo, err := os.Getwd()
	if err != nil {
		return err
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return err
	}
	return linkSettings(
		filepath.Join(repo, "nix/home/mp/modules/tinycast/settings.json"),
		filepath.Join(home, ".config/tinycast/settings.json"), *checkOnly)
}

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
