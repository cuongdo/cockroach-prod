// Copyright 2015 The Cockroach Authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
// implied. See the License for the specific language governing
// permissions and limitations under the License. See the AUTHORS file
// for names of contributors.
//
// Author: Marc Berhault (marc@cockroachlabs.com)

package cli

import (
	"flag"

	"code.google.com/p/go-commander"

	"github.com/cockroachdb/cockroach-prod/docker"
	"github.com/cockroachdb/cockroach/util/log"
)

var startCmd = &commander.Command{
	UsageLine: "start",
	Short:     "start all nodes",
	Long: `
Start all nodes. They must have been previously added and stopped.
`,
	Run:  runStart,
	Flag: *flag.CommandLine,
}

func runStart(cmd *commander.Command, args []string) {
	driver, err := NewDriver(Context)
	if err != nil {
		log.Errorf("could not create driver: %v", err)
		return
	}

	err = driver.Init()
	if err != nil {
		log.Errorf("failed to initialized driver: %v", err)
		return
	}

	// TODO(marc): only get nodes in state "Stopped".
	nodes, err := docker.ListCockroachNodes()
	if err != nil {
		log.Errorf("failed to get list of existing cockroach nodes: %v", err)
		return
	}
	if len(nodes) == 0 {
		log.Errorf("no existing cockroach nodes detected, this means there is probably no existing cluster")
		return
	}

	for _, nodeName := range nodes {
		// Start machine.
		err = docker.StartMachine(nodeName)
		if err != nil {
			log.Errorf("could not start machine %s: %v", nodeName, err)
		}

		// Lookup node info.
		nodeConfig, err := driver.GetNodeConfig(nodeName)
		if err != nil {
			log.Errorf("could not get node config for %s: %v", nodeName, err)
			return
		}

		// Do "start node" logic.
		err = driver.StartNode(nodeName, nodeConfig)
		if err != nil {
			log.Errorf("could not run StartNode steps for %s: %v", nodeName, err)
			return
		}

		// Start the cockroach node.
		err = docker.RunDockerStart(driver, nodeName, nodeConfig)
		if err != nil {
			log.Errorf("could not start cockroach node %s: %v", nodeName, err)
		}
	}
}
