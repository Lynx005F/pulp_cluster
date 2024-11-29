# PULP Cluster (Astral Branch)

![pulp_cluster schematic](doc/PULP_CLUSTER.png)

The `pulp_cluster` repository contains the structure of the cluster subsystem
used in PULP chips. For more details on the internal architecture, see the
README.md in the [`pulp` repository](https://github.com/pulp-platform/pulp).

The [`doc`](doc/) folder contains the draw.io schematic shown above, as well as
the raw source to allow for updates, outlining the most important components in
pulp_cluster, as well as the communication interfaces connecting these. While
not a complete overview of all signals, this is meant as a slightly more
detailed overview that can assist in development. Please be aware that the
schematic may not be 100% accurate.

## Simulation

It is possible to run benchmarks on the cluster, either within
[PULP](https://github.com/pulp-platform/pulp) or as a separate IP. For
simulation within PULP, you can directly go to the PULP repo and follow the
README.

To simulate the cluster on its own, you can perform the following steps.
At IIS you can skip steps 1 and 2 as we already have the dependencies ready.

1. Make sure the PULP RV32 toolchain is in your `PATH`. Please refer to [PULP
   RISCV GCC toolchain](https://github.com/pulp-platform/pulp-riscv-gcc) to use
   a pre-built release.

2. We need RV64 toolchain to compile DPI libraries. To this purpose, export the
   RV64 toolchain to a `RISCV` env variable and also export your questa
   installation path to a `QUESTA_HOME` env variable. Please refer to [RISC-V GNU
   toolchain](https://github.com/riscv-collab/riscv-gnu-toolchain/) to use a
   pre-built RV64 toolchain release.

3. Source the environment to make sure we use the right version of gcc and vsim for build and sim. 
   This will throw the error `.....configs/astral-cluster.sh: No such file or directory` which is ok - we don't have that file yet. 
   ```
   source env/astral-env.sh
   ```

4. Compile the hw:
   ```
   make checkout
   make build
   ```

5. Download the sw stack `pulp-runtime` and bare-metal tests `regression-tests`. 
   For the `astral` and `astral_time_tmr` branches, these are linked as git submodules which you can initialize with:
   ```
   git submodule update --init --recursive
   ```
   Otherwise get them via makefile:
   ```
   make pulp-runtime
   make regression-tests
   ```

6. Source the environment again, this time with the astral configuration
   ```
   source env/astral-env.sh
   ```

7. Run the tests. Choose any test among the `parallel_bare_tests` and the
   `mchan_tests`, move into the related folder and do:

   ```
   make clean all run
   ```

   To use the GUI, add `gui=1` to the previous command.

   For the `fp_redundancy` the following tests are of specific interest:
   - `fpu_test/simple` Quick calc to see if FPU is working
   - `fpu_test/simple_dmr` Quick calc to see if FPU is working in redundant mode
   - `fpu_test/matmul/FP32` matrix multiplication with option to enable redundancy `use_redundancy=1` (and a lot of other options)
   - `hwpe/redmule` matrix multiplication on redmule with option to enable redundancy `use_redundancy=1`
