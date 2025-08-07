package artemis

import rego.v1

warn_unreachable_stage contains msg if {
        stages := {stageId: stageName |
                some i
                input[i].Cmd == "from"
                stageId := input[i].Stage
                stageName := input[i].Value[count(input[i].Value) - 1]
        }

        stageGraph := {node: reachableNodes |
                some id, name in stages
                node := id
                fromNodeIds := [rnode |
                        some i
                        input[i].Stage == id
                        input[i].Cmd == "from"
                        rnode := to_number(input[i].Value[0])]
                fromNodes := [rNode |
                        some i
                        input[i].Stage == id
                        input[i].Cmd == "from"
                        some key, input[i].Value[0] in stages
                        rNode := key]
                copyNodeIds := [rNode |
                        some i
                        input[i].Stage == id
                        input[i].Cmd == "copy"
                        count(input[i].Flags) > 0
                        flagParts := split(input[i].Flags[0], "=")
                        rNode := to_number(flagParts[1])]
                copyNodes := [rNode |
                        some i
                        input[i].Stage == id
                        input[i].Cmd == "copy"
                        count(input[i].Flags) > 0
                        flagParts := split(input[i].Flags[0], "=")
                        some key, flagParts[1] in stages
                        rNode := key]
                t1 := array.concat(fromNodeIds, fromNodes)
                t2 := array.concat(copyNodeIds, copyNodes)
                reachableNodes := array.concat(t1, t2)
        }
        max_stage := max(object.keys(stages))
        reachableFromLast := graph.reachable(stageGraph, [max_stage])
        count(reachableFromLast) != count(object.keys(stages))
        msg := "Some stages are not reachable!"
}