#-- set default radix to symbolic
#radix symbolic
radix hex

# SIGINT Handle
set sim_sigint 0
trap -code {
    set ::sim_sigint 1
    puts "Simulation Stopped*****************"
} SIGINT

# Functions

# Counter monitor
proc proc_wait_for_counter {signal count timeout} {
    puts "Wait for signal"
    set ret 0
    set temp_prev 0
    set timeout_counter 0
    while {[expr [examine -decimal $signal] != $count]} {
        run 100 ns
        incr timeout_counter
        set temp [examine -decimal $signal]
        if {![expr $temp % 5] && $temp != $temp_prev} {
            puts "$signal value: [examine -decimal $signal]"
            set temp_prev $temp
            set ret 0
        }
        # Timeout is reached, return error
        if {$timeout_counter == $timeout} {
            set ret 1
            break
            puts "Error: $signal Timeout"
        }
        # Stop Simulation
        if {$::sim_sigint} {
            set ret 1
            break
        }
    }
    return $ret
}

# State Monitor
proc proc_wait_for_state {signal state timeout} {
    puts "Wait for signal"
    set ret 0
    set temp_prev 0
    set timeout_counter 0
    while {[string compare [examine $signal] $state] != 0} {
        run 100 ns
        incr timeout_counter
        set temp [examine $signal]

        # Timeout is reached, return error
        if {$timeout_counter == $timeout} {
            set ret 1
            break
            puts "Error: $signal Timeout"
            set ret 1
        } else {
            set ret 0
        }

        # Stop simulation
        if {$::sim_sigint} {
            set ret 1
            break
        }
    }
    puts "State: [examine -decimal $signal]."
    return $ret
}

proc verify_test {err msg} {
    set RED   "\033\[0;31m"
    set GREEN "\033\[0;32m"
    set NC    "\033\[0m"
    if {!$err} {
        puts "------------------------------"
        puts "$GREEN PASSED $NC: $msg"
        puts "------------------------------"
    } else {
        puts "------------------------------"
        puts "$RED FAILED $NC: Test Passed $msg"
        puts "------------------------------"
    }
}

mem load -infile image_in.mif -format hex -filltype value -filldata 1'b0 /tb_fpga/image_rom_inst

# Configure module
force w_reg_enable_correction 1
force w_reg_line_length       16#146
force w_reg_center_x          16#A2
force w_reg_center_y          16#63

# setup an oscillator on the CLK input
force i_sim_clk 1 50 ns -r 100 ns
force i_sim_clk 0 100 ns -r 100 ns

# reset the clock and then counter to 100
force i_sim_aresetn 0
run 400 ns

puts ""
puts "------------------------------------------"
puts " Simulation START"
puts "------------------------------------------"
puts ""
force i_sim_aresetn 1


# ---------------------------------------
# TEST: Wait for counter to reach 100
# ---------------------------------------
run 100 ns
force w_reg_enable_correction 0
set err 0
set sim_timeout 100000

# ---------------------------------------
# TEST: Wait for frame counter to reach 1
# ---------------------------------------
# Wait for couple of lines
#set err [proc_wait_for_counter w_debug_line_counter 199 $sim_timeout]
set err [proc_wait_for_counter /tb_fpga/dist_correction_inst/r_pixel_counter_y 199 $sim_timeout]
verify_test $err "Image Correction"

# Wait for couple of lines
set err [proc_wait_for_state /tb_fpga/dist_correction_inst/r_control_fsm "sDONE" $sim_timeout]
verify_test $err "Distortion Correction FSM is Done"

run 2000

puts ""
puts "------------------------------------------"
puts " Simulation DONE"
puts "------------------------------------------"
puts ""

exit
