\# AXI4-Lite UART IP Core



A custom AXI4-Lite UART IP Core implemented in VHDL using AMD Vivado.



\## Project Overview



This project implements a UART peripheral that can be accessed through an AXI4-Lite memory-mapped interface. The design combines UART communication with FPGA-based processor and bus integration.



\## Features



\- AXI4-Lite slave interface

\- UART TX and RX

\- Configurable baud-rate generation

\- TX and RX FIFOs

\- UART status monitoring

\- Hardware flow control using CTS/RTS

\- Interrupt generation

\- Interrupt status handling with Write-1-to-Clear (W1C)

\- VHDL RTL implementation

\- Functional simulation testbenches

\- Vivado synthesis and implementation

\- FPGA bitstream generation

\- Packaged IP repository



\## Architecture



```text

&#x20;               AXI4-Lite Interface

&#x20;                       |

&#x20;                       v

&#x20;             +-------------------+

&#x20;             |   AXI UART Core   |

&#x20;             |-------------------|

&#x20;             | Control Registers |

&#x20;             | Status Registers  |

&#x20;             | Interrupt Logic   |

&#x20;             | TX/RX FIFOs       |

&#x20;             +---------+---------+

&#x20;                       |

&#x20;            +----------+----------+

&#x20;            |                     |

&#x20;            v                     v

&#x20;       UART Transmitter      UART Receiver

&#x20;            |                     |

&#x20;          UART TX               UART RX

