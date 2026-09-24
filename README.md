# AXI4-Lite UART IP Core

A custom AXI4-Lite UART IP Core implemented in VHDL using AMD Vivado.

## Project Overview

This project implements a UART peripheral that can be accessed through an AXI4-Lite memory-mapped interface. The design combines UART communication with FPGA-based processor and bus integration.

## Features

- AXI4-Lite slave interface
- UART TX and RX
- Configurable baud-rate generation
- TX and RX FIFOs
- UART status monitoring
- Hardware flow control using CTS/RTS
- Interrupt generation
- Interrupt status handling with Write-1-to-Clear (W1C)
- VHDL RTL implementation
- Functional simulation testbenches
- Vivado synthesis and implementation
- FPGA bitstream generation
- Packaged IP repository

## Architecture

```text
                AXI4-Lite Interface
                        |
                        v
              +-------------------+
              |   AXI UART Core   |
              |-------------------|
              | Control Registers |
              | Status Registers  |
              | Interrupt Logic   |
              | TX/RX FIFOs       |
              +---------+---------+
                        |
             +----------+----------+
             |                     |
             v                     v
        UART Transmitter      UART Receiver
             |                     |
           UART TX               UART RX
