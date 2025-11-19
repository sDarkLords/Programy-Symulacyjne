#!/bin/bash

####################
#Description: Function that saves simulation results to a file
#Globals: None
#Arguments $1-output file name
#       $2-content to be saved
#Outputs: File with simulation results
#Returns: 0 if successful, 1 if save error
####################
function save_to_file {
    local output_file=$1
    local content=$2

    if echo "$content" > "$output_file"; then
        echo "The results were recorded in $output_file"
        return 0
    else
        echo "Error while saving to file $output_file" >&2
        return 1
    fi
}

####################
#Description: Function generating process data (names and execution times)
#Globals: PROCESS_NAMES;PROCESS_BURSTS
#Arguments: $1-number of processes to generate
#Outputs: “process_data.txt” file with generated data
#Returns: 0 if successful, non-zero if an error occurred
####################
function generate_process_data {
    local process_count=$1 # Number of processes passed as an argument
    local output_file="process_data.txt" # Output file name
    local -a processes # Process name board 
    local -a bursts # Board for completion times 

    echo "Generating $process_count processes"
    
    #Generating process names (P1, P2, ...) and random execution times 
    for ((i=1; i<=$process_count; i++)); do
        processes[$i-1]="P$i" # Process name
        bursts[$i-1]=$((RANDOM % 10 + 1))  # Random execution time 
    done

    # Saving data to a file
    echo "Processes: ${processes[@]}" > $output_file # Recording process names 
    echo "Execution_times: ${bursts[@]}" >> $output_file # Recording execution times 

    echo "Process data was saved in $output_file"
    echo ""

    # Assigning data to global variables 
    PROCESS_NAMES=("${processes[@]}") # Global process name table 
    PROCESS_BURSTS=("${bursts[@]}") # Global execution time table
}

####################
#Description: Function that retrieves the number of processes (minimum 1) from the user
#Globals: None
#Arguments $1-number of processes provided by the user 
#Outputs: Number of processes
#Returns: 0 if successful, 1 if the number of processes is invalid
####################
function read_process_count {
    while true; do # Infinite loop (until correct input)
        read -p "Enter the number of processes (minimum 1): " process_count
        # Data validation 
        if [[ $process_count =~ ^[1-9][0-9]*$ ]]; then
            break # Exit the loop if the value is correct
        else
            echo "Invalid value. Enter an integer greater than 0."
        fi
    done
}

####################
#Description: Function simulating the FCFS (First Come First Served) algorithm
#Globals: None 
#Arguments: $1—reference to the process name array (indirect reference)
#        $2—reference to the execution time array (indirect reference)
#Outputs: Table with results for each process
#      Average waiting and processing times 
#Returns: 0 always successful
####################
function fcfs {
    local p=("${!1}")    # Process name table
    local bt=("${!2}")   # Performance times table
    
    local time=0 # Current system time
    local total_waiting=0 # Total waiting time
    local total_turnaround=0 # Total processing time
    local count=${#p[@]} # Number of processes
    
    # Results table header
    echo "FCFS Scheduling:"
    echo "Process | Burst | Waiting | Turnaround"
    echo "--------|-------|---------|-----------"
    
    # Loop calculating times for each process
    for ((i=0; i<$count; i++)); do
        local waiting=$time # Waiting time = current system time
        local turnaround=$((waiting + bt[i])) # Processing time = waiting + execution
        
        # Displaying the results row
        printf "%7s | %5d | %7d | %10d\n" "${p[i]}" "${bt[i]}" "$waiting" "$turnaround"
        
        # Update totals
        total_waiting=$((total_waiting + waiting))
        total_turnaround=$((total_turnaround + turnaround))
        time=$((time + bt[i])) # System time incrementation
    done
    
    # Calculation of average times
    local avg_waiting=$((total_waiting / count))
    local avg_turnaround=$((total_turnaround / count))
    
    # Displaying averages
    echo "Average Waiting Time: $avg_waiting"
    echo "Average Turnaround Time: $avg_turnaround"
}

####################
#Description: Function simulating the Round Robin algorithm
#Globals: None
#Arguments: $1—reference to the process name array (indirect reference)
#       $2—reference to the execution time array (indirect reference)
#       $3-quantum value
#Outputs: Execution details (for <= 20 processes)
#      Summary of waiting and processing times
#Returns: 0 always successful
####################
function round_robin {
    local p=("${!1}")    # Process name table
    local bt=("${!2}")   # Performance times table
    local q=$3           # Quantum
    
    local count=${#p[@]} # Number of processes
    local remaining=("${bt[@]}") # Table of remaining execution times
    local waiting=() # Waiting times board
    local turnaround=() # Processing times table
    local time=0 # Current system time
    local completed=0 # Number of completed processes
    
    # Initialize the waiting and turnaround arrays with zeros
    for ((i=0; i<$count; i++)); do
        waiting[$i]=0
        turnaround[$i]=0
    done
    
    echo "Round Robin Scheduling (Quantum: $q):"
    
    # Compact view for a large number of processes
    if [ $count -gt 20 ]; then
        echo "Too many processes to display details. Only showing summary."
    else
    	# Formatted simulation results table
        echo "Time | Process | Remaining"
        echo "-----|---------|----------"
    fi
    
    # Main simulation loop
    # Runs until all processes are completed
    while [ $completed -lt $count ]; do
    	# Iterate through all processes in the queue
        for ((i=0; i<$count; i++)); do
            # Checking whether the process still needs CPU time
            if [ ${remaining[$i]} -gt 0 ]; then
            	# Case 1: The process takes longer than quantum time
                if [ ${remaining[$i]} -gt $q ]; then
                    # Display details (only for <= 20 processes)
                    if [ $count -le 20 ]; then 
                        echo "$time | ${p[$i]} | ${remaining[$i]} -> $((remaining[i] - q))"
                    fi
                    
                    # Update simulation time and remaining process time
                    time=$((time + q))
                    remaining[$i]=$((remaining[i] - q))
                # Case 2: The process ends within this amount of time
                else
                    if [ $count -le 20 ]; then
                        echo "$time | ${p[$i]} | ${remaining[$i]} -> 0"
                    fi
                    
                    # Simulation time update
                    time=$((time + remaining[$i]))
                    # Remembering turnaround time
                    turnaround[$i]=$time
                    # Marking the process as complete
                    remaining[$i]=0
                    completed=$((completed + 1))
                fi
                
                # Update wait time for other processes
                for ((j=0; j<$count; j++)); do
                    if [ $j -ne $i ] && [ ${remaining[$j]} -gt 0 ]; then
                    	# Add the execution time of the current process (q or less)
                        waiting[$j]=$((waiting[j] + (remaining[$i] > q ? q : remaining[$i])))
                    fi
                done
            fi
        done
    done
    
    # Calculating and displaying the summary
    local total_waiting=0
    local total_turnaround=0
    
    echo ""
    echo "Process | Waiting | Turnaround"
    echo "--------|---------|-----------"
    
    # For >50 processes, the script only shows a summary
    if [ $count -gt 50 ]; then
        echo "[... pokazano pierwsze i ostatnie 5 procesów ...]"
        local show_count=$((count < 10 ? count : 5))
        
        # Display the first 5 processes
        for ((i=0; i<$show_count; i++)); do
            printf "%7s | %7d | %10d\n" "${p[i]}" "${waiting[i]}" "${turnaround[i]}"
            total_waiting=$((total_waiting + waiting[i]))
            total_turnaround=$((total_turnaround + turnaround[i]))
        done
        
        echo "[... pominięto $((count - 2*show_count)) procesów ...]"
        
        # Display the last 5 processes
        for ((i=$((count-show_count)); i<$count; i++)); do
            printf "%7s | %7d | %10d\n" "${p[i]}" "${waiting[i]}" "${turnaround[i]}"
            total_waiting=$((total_waiting + waiting[i]))
            total_turnaround=$((total_turnaround + turnaround[i]))
        done
    else
        # Display all processes
        for ((i=0; i<$count; i++)); do
            printf "%7s | %7d | %10d\n" "${p[i]}" "${waiting[i]}" "${turnaround[i]}"
            total_waiting=$((total_waiting + waiting[i]))
            total_turnaround=$((total_turnaround + turnaround[i]))
        done
    fi
    
    # Calculation of average times
    local avg_waiting=$((total_waiting / count))
    local avg_turnaround=$((total_turnaround / count))
    
    # Display summary
    echo ""
    echo "Average Waiting Time: $avg_waiting"
    echo "Average Turnaround Time: $avg_turnaround"
    echo "Total Processes: $count"
}
####################
#Description: Function comparing the performance of FCFS and Round Robin algorithms.
#Globals: PROCESS_NAMES;PROCESS_BURSTS
#Arguments: No direct arguments (uses global variables)
#Outputs: Full FCFS simulation results:
#            For each process: name, execution time, waiting time, processing time)
#            Average waiting and processing times
#      Full Round Robin simulation results:
#            Execution details (for <=20 processes)
#            Process waiting and processing times
#            Average times and summaries
#Returns: 0 always success
####################
function compare_schedulers {
    # Preparing input data
    local process_names=("${PROCESS_NAMES[@]}") # Copying the global process name table
    local process_bursts=("${PROCESS_BURSTS[@]}") # Copying the global execution time table
    local quantum=5 # Determining the time quantum for Round Robin
    
    # Display comparison header
    echo ""
    echo "=== Comparison of FCFS and Round Robin ==="
    echo "Number of processes: ${#process_names[@]}"
    
    # Conditional display of process details (only for <=20 processes)
    if [ ${#process_names[@]} -le 20 ]; then
        echo "Processes: ${process_names[@]}"
        echo "Execution times: ${process_bursts[@]}"
    else
        echo "[Too many processes to display the list]"
    fi
    echo ""
    
    # Performing an FCFS simulation
    echo "== FCFS =="
    fcfs process_names[@] process_bursts[@] # Calling the FCFS function with array passing
    
    # Performing a Round Robin simulation
    echo ""
    echo "== Round Robin (quantum=$quantum) =="
    round_robin process_names[@] process_bursts[@] $quantum 
}

clear # Cleaning the terminal screen before starting
echo "=== Process planning algorithm simulator ===" # Program header

# Collecting data from the user 
read_process_count

# Process data generation
generate_process_data $process_count

# Performing simulations and capturing results
simulation_results=$(
    echo "=== Simulation results ==="
    echo "Number of processes: $process_count"
    echo ""
    compare_schedulers
)

# Displaying results on screen
echo "$simulation_results"

# Saving results to a file
save_to_file "simulation_results.txt" "$simulation_results"


# Final comic strip
echo ""
echo "Simulation complete."
