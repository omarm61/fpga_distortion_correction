
#-- set default radix to symbolic
#radix symbolic
radix hex


#when -label a {v_line_index == 10} {puts "v_line_index = [examine v_line_index]"}

# Functions
proc proc_wait_for_counter {signal count} {
    puts "Wait for signal"
        set temp_prev 0
        while {[expr [examine -decimal $signal] != $count]} {
            run 100 ns
                set temp [examine -decimal $signal]
                if {![expr $temp % 5] && $temp != $temp_prev} {
                    puts "$signal value: [examine -decimal $signal]"
                    set temp_prev $temp
                }
        }
    puts "Counter: Counting to 100 failed. COUNT is [examine -decimal $signal]."
}

proc proc_wait_for_state {signal state} {
    puts "Wait for signal"
        set temp_prev 0
        while {[string compare [examine $signal] $state] != 0} {
            run 100 ns
                set temp [examine $signal]
        }
    puts "State: [examine -decimal $signal]."
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

# ---------------------------------------
# TEST: Wait for frame counter to reach 1
# ---------------------------------------
# Wait for couple of lines
proc_wait_for_counter /tb_fpga/dist_correction_inst/r_pixel_counter_y 199
verify_test 0 "Video Input"

# Wait for couple of lines
proc_wait_for_state /tb_fpga/dist_correction_inst/r_control_fsm "sDONE"

run 20000

puts ""
puts "------------------------------------------"
puts " Simulation DONE"
puts "------------------------------------------"
puts ""

exit
