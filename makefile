# Simulation Direcotry
SIM_DIR="sim"
TB_DIR="tb"
SCRIPT_DIR="scripts"
C_MODEL_DIR="c_model"

# Input Image
IMAGE_IN_JPEG="../pictures/checkerboard_326x200.jpg"
IMAGE_IN_MIF="image_in.mif"
CORR_LUT_MIF="corr_lut.mif"

GAIN=1.7

# RTL directories
INCLUDE_RTL= ../rtl/distortion_correction/dsp48_wrap.vhd \
			 ../rtl/distortion_correction/calc_pixel_position.vhd \
			 ../rtl/distortion_correction/calc_pixel_address.vhd \
			 ../rtl/distortion_correction/dist_correction.vhd

# TB direcotry
INCLUDE_TB= ../tb/image_rom.vhd \
			../tb/tb_fpga.vhd

# Xilinx compiled lib directory
XILINX_LIB=/opt/xilinx_sim_lib/

ifeq ($(LOG), )
	LOG=0
endif

# Modelsim options
VSIM_OPT = -onfinish stop \
		   -do "set sim_log $(LOG)"\
		   -do myfile \
		   -wlf output.wlf

# Waveform Configuration
WAVE_DO=wave.do

#ifeq ($(WAVES), 1)
#	VSIM_OPT += -wlf output.wlf
#endif

ifneq ($(GUI), 1)
	VSIM_OPT += -batch
endif

ifeq ($(GAMMA), )
	GAMMA=1.4
endif


ifneq (,$(wildcard ./sim/$(WAVE_DO)))
	WAVE_OPT = "view signal list wave; radix hex; source wave.do"
else
	WAVE_OPT = "view signal list wave; radix hex"
endif

#==================
# Targets
#==================

.DEFAULT_GOAL := help
.PHONY: help


## setup: Copies xilinx simulation library and configure simulation directory
setup : stim
	@cd $(SIM_DIR); \
	cp $(XILINX_LIB)/modelsim.ini .; \
	vlib work; \
	vmap work work

## compile: compiles the RTL code (NOTE: The files are recompiled before every simulation run)
compile :
	@cd $(SIM_DIR); \
	vcom $(INCLUDE_RTL) $(INCLUDE_TB)

## sim: run simulation
sim : compile stim
	@cd $(SIM_DIR); \
	vsim $(VSIM_OPT) tb_fpga

## waves: Open wave files
waves :
	@cd $(SIM_DIR); \
	vsim -view output.wlf -do $(WAVE_OPT)

## stim: generate stimulus input video file
stim :
	@cd $(SCRIPT_DIR); \
	python3 generate_image_rom.py -i $(IMAGE_IN_JPEG) -o ../$(SIM_DIR)/$(IMAGE_IN_MIF); \
	python3 generate_corr_lut.py -w 326 -l 200 -s $(GAIN) -o ../$(SIM_DIR)/$(CORR_LUT_MIF)

plot_lut :
	@cd $(SCRIPT_DIR); \
	python3 plot_atan_lut.py

## conv: generate yuv file
conv :
	@cd $(SIM_DIR); \
	rm video_out.yuv; \
	cat ./video_out_sim.txt | tr -d "\n" >> ./video_out.yuv

## play: play the generated video
play : conv
	@cd $(SIM_DIR); \
	ffplay -f rawvideo -pixel_format yuyv422  -video_size 326x199 video_out.yuv

## play: play the generated video
display : conv
	@cd $(SCRIPT_DIR); \
	python3 display_sim_image.py -a ../pictures/checkerboard_326x200.jpg -b ../sim/video_out.yuv -d

## clean: remove all generated files in /sim directory
clean :
	find $(SIM_DIR) ! -name 'myfile' ! -name 'stim.do' -type f -exec rm -f {} +; \
	find $(SIM_DIR) ! -name 'myfile' ! -name 'stim.do' ! -name '.' -type d -exec rm -rf {} +

help: makefile
	@echo "------------------------------------------------------------\n"
	@echo "Make Options:"
	@echo ""
	@sed -n 's/^##/ -/p' $<
	@echo ""
	@echo "------------------------------------------------------------\n"
