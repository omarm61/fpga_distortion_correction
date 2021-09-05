
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

# Configure module

# setup an oscillator on the CLK input
force i_sim_clk 1 50 ns -r 100 ns
force i_sim_clk 0 100 ns -r 100 ns

# reset the clock and then counter to 100
force i_sim_aresetn 0
run 400 ns
if {[examine counter] != 0} {
	echo "!!! Error: Reset failed. COUNT is [examine counter]."
} else {
	echo "Reset OK. COUNT is [examine counter]."
}

puts ""
puts "------------------------------------------"
puts " Simulation START"
puts "------------------------------------------"
puts ""
force i_sim_aresetn 1


# ---------------------------------------
# TEST: Wait for counter to reach 100
# ---------------------------------------

# ---------------------------------------
# TEST: Wait for frame counter to reach 1
# ---------------------------------------
verify_test 0 "Video Input"

run 10000

puts ""
puts "------------------------------------------"
puts " Simulation DONE"
puts "------------------------------------------"
puts ""

exit
