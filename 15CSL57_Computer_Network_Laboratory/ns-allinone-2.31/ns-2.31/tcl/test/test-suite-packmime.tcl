# test-suite-PackMime.tcl
#
# Based on ns/tcl/test/test-suite-full.tcl
#
# Modified by Michele Weigle, UNC-Chapel Hill, Dec 2003
#

#*************************************************************************
# Tests to validate PackMime
#
#  1node-http1_0 - one PackMime node running HTTP 1.0
#  1node-http1_1 - one PackMime node running HTTP 1.1
#  2node-http1_1 - two PackMime nodes running HTTP 1.1
#
#*************************************************************************

source misc.tcl

TestSuite instproc finish testname {
	$self instvar ns_
	$ns_ halt
}

Class SkelTopology

Class Topology -superclass SkelTopology

Topology instproc node? num {
    $self instvar node_
    return $node_($num)
}

Class Topology/DB -superclass Topology

#
# PackMime test topology
#
#           s1                      k1
#             \                    /
#  100Mb, 1ms  \    100Mb, 1ms    / 100Mb, 1ms
#               r1 ----------- r2 
#  100Mb, 1ms  /                 \ 100Mb, 1ms
#             /                   \
#          s2                       k2
#
Topology/DB instproc init ns {
    $self instvar node_
    set node_(s1) [$ns node]
    set node_(s2) [$ns node]
    set node_(r1) [$ns DelayBox]
    set node_(r2) [$ns DelayBox]
    set node_(k1) [$ns node]
    set node_(k2) [$ns node]

    $self next
    $ns duplex-link $node_(s1) $node_(r1) 100Mb 1ms DropTail
    $ns duplex-link $node_(s2) $node_(r1) 100Mb 1ms DropTail
    $ns duplex-link $node_(r1) $node_(r2) 100Mb 1ms DropTail
    $ns duplex-link $node_(k1) $node_(r2) 100Mb 1ms DropTail
    $ns duplex-link $node_(k2) $node_(r2) 100Mb 1ms DropTail
}

TestSuite instproc setup_topo {} {
    $self instvar ns_ node_ testName_

    # clear output files
    exec rm -f temp.rands

    remove-all-packet-headers
    add-packet-header IP TCP
    $ns_ use-scheduler Heap

    Trace set show_tcphdr_ 1 
    Agent/TCP set minrto_ 1;     # ns-2.27 value

   # setup tracing
    set trace_file [open temp.rands w]
    $ns_ trace-queue $node_(s1) $node_(r1) $trace_file
    $ns_ trace-queue $node_(r1) $node_(s1) $trace_file
    $ns_ trace-queue $node_(s2) $node_(r1) $trace_file
    $ns_ trace-queue $node_(r1) $node_(s2) $trace_file
    $ns_ trace-queue $node_(r1) $node_(r2) $trace_file
    $ns_ trace-queue $node_(r2) $node_(r1) $trace_file
    $ns_ trace-queue $node_(k1) $node_(r2) $trace_file
    $ns_ trace-queue $node_(r2) $node_(k1) $trace_file
    $ns_ trace-queue $node_(k2) $node_(r2) $trace_file
    $ns_ trace-queue $node_(r2) $node_(k2) $trace_file

    # create random variables
    set srcd_rng [new RNG];
    set src_delay [new RandomVariable/Uniform];   # delay 20-50 ms
    $src_delay set min_ 20
    $src_delay set max_ 50
    $src_delay use-rng $srcd_rng

    set srcbw_rng [new RNG];
    set src_bw [new RandomVariable/Uniform];      # bw 1-20 Mbps
    $src_bw set min_ 1
    $src_bw set max_ 20
    $src_delay use-rng $srcbw_rng

    set sinkd_rng [new RNG];
    set sink_delay [new RandomVariable/Uniform];   # delay 1-20 ms
    $sink_delay set min_ 1
    $sink_delay set max_ 20
    $sink_delay use-rng $sinkd_rng

    set sinkbw_rng [new RNG];
    set sink_bw [new RandomVariable/Constant];      # bw 100 Mbps
    $sink_bw set val_ 100
    $sink_bw use-rng $sinkbw_rng

    set loss_rng [new RNG];
    set loss_rate [new RandomVariable/Uniform];    # loss 0-1%
    $loss_rate set min_ 0
    $loss_rate set max_ 0.01
    $loss_rate use-rng $loss_rng
    
    # setup rules for DelayBoxes
    $node_(r1) add-rule [$node_(s1) id] [$node_(k1) id] $src_delay \
	    $loss_rate $src_bw
    $node_(r1) add-rule [$node_(s2) id] [$node_(k2) id] $src_delay \
	    $loss_rate $src_bw
    $node_(r2) add-rule [$node_(s1) id] [$node_(k1) id] $sink_delay \
	    $loss_rate $sink_bw
    $node_(r2) add-rule [$node_(s2) id] [$node_(k2) id] $sink_delay \
	    $loss_rate $sink_bw
}

#
# 1node-http_1_0
#
Class Test/1node-http_1_0 -superclass TestSuite
Test/1node-http_1_0 instproc init topo {
        global defaultRNG
	$self instvar net_ defNet_ test_
        $defaultRNG seed 9999
        set net_ $topo
	set defNet_ DB
	set test_ 1node-http_1_0
	$self next 0
}

Test/1node-http_1_0 instproc run {} {
	$self instvar ns_ node_
        $self setup_topo

        set PM [new PackMimeHTTP]
        $PM set-server $node_(s1)
        $PM set-client $node_(k1)
        $PM set-rate 10
#        $PM set-outfile temp.rands

        $ns_ at 0 "$PM start"
        $ns_ at 5 "$PM stop"

	$ns_ run
}

#
# 1node-http_1_1
#
Class Test/1node-http_1_1 -superclass TestSuite
Test/1node-http_1_1 instproc init topo {
        global defaultRNG
	$self instvar net_ defNet_ test_
        $defaultRNG seed 9999
        set net_ $topo
	set defNet_ DB
	set test_ 1node-http_1_1
	$self next 0
}
Test/1node-http_1_1 instproc run {} {
	$self instvar ns_ node_
        $self setup_topo

        set PM [new PackMimeHTTP]
        $PM set-server $node_(s1)
        $PM set-client $node_(k1)
#        $PM set-outfile temp.rands
        $PM set-rate 5
        $PM set-1.1

        $ns_ at 0 "$PM start"
        $ns_ at 5 "$PM stop"

	$ns_ run
}

#
# 2node-http_1_1
#
Class Test/2node-http_1_1 -superclass TestSuite
Test/2node-http_1_1 instproc init topo {
        global defaultRNG
	$self instvar net_ defNet_ test_
        $defaultRNG seed 9999
        set net_ $topo
	set defNet_ DB
	set test_ 2node-http_1_1
	$self next 0
}
Test/2node-http_1_1 instproc run {} {
	$self instvar ns_ node_
        $self setup_topo

        set PM [new PackMimeHTTP]
        $PM set-server $node_(s1)
        $PM set-client $node_(k1)
        $PM set-server $node_(s2)
        $PM set-client $node_(k2)
#        $PM set-outfile temp.rands
        $PM set-rate 5
        $PM set-1.1
    
        $ns_ at 0 "$PM start"
        $ns_ at 5 "$PM stop"

	$ns_ run
}

TestSuite runTest
