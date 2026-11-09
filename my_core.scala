package vexriscv.demo

import vexriscv.plugin._
import vexriscv.{plugin, VexRiscv, VexRiscvConfig}
import spinal.core._
import spinal.lib._
import spinal.lib.bus.amba4.axi._

// Module Wrapper: Bọc nhân CPU Không Cache và chuyển giao tiếp sang AXI4
class VexRiscvAxi4NoCache extends Component {
  val cpuConfig = VexRiscvConfig(
    plugins = List(
      // 1. Bus Lệnh & Bus Dữ liệu Tối giản (Không Cache)
      new IBusSimplePlugin(
        resetVector = 0x80000000L, // Địa chỉ RAM khởi động CPU
        prediction = NONE
      ),
      new DBusSimplePlugin(
        catchAddressMisaligned = true,
        catchAccessFault = true
      ),

      // 2. Bộ giải mã & Bảng thanh ghi (RV32I)
      new DecoderSimplePlugin(catchIllegalInstruction = true),
      new RegFilePlugin(regFileReadyKind = plugin.SYNC, zeroBoot = false),

      // 3. Khối tính toán ALU & Xử lý đường ống (Pipeline)
      new IntAluPlugin,
      new SrcPlugin(separatedAddSub = false, executeInsertion = true),
      new FullBarrelShifterPlugin,
      new HazardSimplePlugin(
        bypassExecute           = true,
        bypassMemory            = true,
        bypassWriteBack         = true,
        bypassWriteBackBuffer   = true,
        pessimisticUseSrc       = false,
        pessimisticWriteRegFile = false,
        pessimisticAddressMatch = false
      ),
      new BranchPlugin(earlyBranch = false, catchAddressMisaligned = true),

      // 4. Ngắt (Interrupt) & Debug JTAG
      new CsrPlugin(CsrPluginConfig.small(0x80000020L)),
      new DebugPlugin(ClockDomain.current.clone(reset = Bool().setName("debugReset"))),
      new YamlPlugin("cpu0.yaml")
    )
  )

  // Khởi tạo Core CPU
  val cpu = new VexRiscv(cpuConfig)

  // Khai báo các cổng bus AXI4 chuẩn ở chân ra của Module
  val iBusAxi = master(Axi4ReadOnly(Axi4Config(addressWidth = 32, dataWidth = 32, idWidth = 1)))
  val dBusAxi = master(Axi4(Axi4Config(addressWidth = 32, dataWidth = 32, idWidth = 1)))

  // Nối cầu chuyển đổi từ SimpleBus sang AXI4
  iBusAxi << cpu.iBus.toAxi4ReadOnly()
  dBusAxi << cpu.dBus.toAxi4()
}

// Điểm chạy chính để sinh file Verilog
object my_core extends App {
  SpinalVerilog(new VexRiscvAxi4NoCache)
}