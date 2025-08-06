# frozen_string_literal: true

require 'spec_helper'
require 'rtp/receiver'

Thread.abort_on_exception = true

describe RTP::Receiver do
  describe '#initialize' do
    it 'sets default values for accessors' do
      expect(subject.transport_protocol).to eql(:UDP)
      expect(subject.instance_variable_get(:@ip_address)).to eql('0.0.0.0')
      expect(subject.rtp_port).to eql(6970)
      expect(subject.rtcp_port).to eql(6971)
      expect(subject.capture_file).to be_a(Tempfile)
    end

    it "isn't running" do
      expect(subject).to_not be_running
    end
  end

  describe '#start' do
    context 'running' do
      before { allow(subject).to receive(:running?).and_return(true) }

      it "doesn't try starting anything else" do
        expect(subject).not_to receive(:start_packet_writer)
        expect(subject).not_to receive(:init_socket)
        expect(subject).not_to receive(:start_listener)
        subject.start
      end
    end

    context 'not running' do
      before { allow(subject).to receive(:running?).and_return(false) }
      let(:packet_writer) { double '@packet_writer', :abort_on_exception= => nil }
      let(:listener) { double '@listener', :abort_on_exception= => nil }

      it 'initializes the listener socket, listener thread, and packet writer' do
        expect(subject).to receive(:start_packet_writer).and_return(packet_writer)
        expect(subject).to receive(:init_socket).with(:UDP, 6970, '0.0.0.0')
        expect(subject).to receive(:start_listener).and_return(packet_writer)

        subject.start
      end
    end
  end

  describe '#stop' do
    context 'running' do
      before { allow(subject).to receive(:running?).and_return(true) }

      it 'calls #stop_listener' do
        expect(subject).to receive(:stop_listener)
        subject.stop
      end

      it 'calls #stop_packet_writer' do
        expect(subject).to receive(:stop_packet_writer)
        subject.stop
      end
    end

    context 'not running' do
      before { allow(subject).to receive(:running?).and_return(false) }
      specify { expect(subject.stop).to be_falsey }
    end
  end

  describe '#listening?' do
    context '@listner is nil' do
      before { subject.instance_variable_set(:@listener, nil) }
      specify { expect(subject).to_not be_listening }
    end

    context '@listener is not nil' do
      let(:listener) { double '@listener', alive?: true }
      before { subject.instance_variable_set(:@listener, listener) }
      specify { expect(subject).to be_listening }
    end
  end

  describe '#writing_packets?' do
    context '@packet_writer is nil' do
      before { subject.instance_variable_set(:@packet_writer, nil) }
      specify { expect(subject).not_to be_writing_packets }
    end

    context '@packet_writer is not nil' do
      let(:writer) { double '@packet_writer', alive?: true }
      before { subject.instance_variable_set(:@packet_writer, writer) }
      specify { expect(subject).to be_writing_packets }
    end
  end

  describe '#running?' do
    context 'listening and writing packets' do
      before do
        allow(subject).to receive(:listening?).and_return(true)
        allow(subject).to receive(:writing_packets?).and_return(true)
      end

      specify { expect(subject).to be_running }
    end

    context 'listening, not writing packets' do
      before do
        allow(subject).to receive(:listening?).and_return(true)
        allow(subject).to receive(:writing_packets?).and_return(false)
      end

      specify { expect(subject).not_to be_running }
    end

    context 'not listening, writing packets' do
      before do
        allow(subject).to receive(:listening?).and_return(false)
        allow(subject).to receive(:writing_packets?).and_return(true)
      end

      specify { expect(subject).not_to be_running }
    end

    context 'not listening, not writing packets' do
      before do
        allow(subject).to receive(:listening?).and_return(false)
        allow(subject).to receive(:writing_packets?).and_return(false)
      end

      specify { expect(subject).not_to be_running }
    end
  end

  describe '#rtp_port=' do
    specify do
      expect(subject.rtp_port).to eq(6970)
      expect(subject.rtcp_port).to eq(6971)

      subject.rtp_port = 10_000

      expect(subject.rtp_port).to eq(10_000)
      expect(subject.rtcp_port).to eq(10_001)
    end
  end

  #----------------------------------------------------------------------------
  # PRIVATES
  #----------------------------------------------------------------------------

  describe '#start_packet_writer' do
    context 'packet writer running' do
      let(:packet) { double 'RTP::Packet' }
      let(:msg) { 'the data' }
      let(:timestamp) { '12345' }

      let(:packets) do
        p = double('Queue')
        expect(p).to receive(:pop).and_return([msg, timestamp])

        p
      end

      before do
        expect(Thread).to receive(:start).and_yield
        expect(subject).to receive(:loop).and_yield
        expect(RTP::Packet).to receive(:read).with(msg).and_return(packet)
        subject.instance_variable_set(:@packets, packets)
      end

      context '@strip_headers is false' do
        before { subject.instance_variable_set(:@strip_headers, false) }

        it 'adds the incoming data to @packets Queue' do
          expect(packet).not_to receive(:rtp_payload)
          expect(subject.instance_variable_get(:@capture_file)).to receive(:write)
                 .with packet
          subject.send(:start_packet_writer)
        end
      end

      context '@strip_headers is true' do
        before { subject.instance_variable_set(:@strip_headers, true) }

        it 'adds the stripped data to @payload_data buffer' do
          expect(packet).to receive(:rtp_payload).and_return('payload_data')
          expect(subject.instance_variable_get(:@capture_file)).to receive(:write)
                 .with 'payload_data'
          subject.send(:start_packet_writer)
        end
      end

      context 'block is given' do
        it 'yields the data and its timestamp' do
          expect do |block|
            subject.send(:start_packet_writer, &block)
          end.to yield_with_args packet, timestamp
        end
      end

      context 'no block given' do
        let(:capture_file) do
          c = double '@capture_file'
          allow(c).to receive(:closed?)

          c
        end

        before { subject.instance_variable_set(:@capture_file, capture_file) }

        it 'writes to the capture file' do
          expect(subject.instance_variable_get(:@capture_file)).to receive(:write)
                 .with(packet)

          subject.send(:start_packet_writer)
        end

        it 'adds timestamps to @timestamps' do
          allow(subject.instance_variable_get(:@capture_file)).to receive(:write)
          expect(subject.instance_variable_get(:@packet_timestamps)).to receive(:<<).with(timestamp)

          subject.send(:start_packet_writer)
        end
      end
    end

    context 'packet writer not running' do
      let(:packet_writer) { double '@packet_writer' }

      before do
        subject.instance_variable_set(:@packet_writer, packet_writer)
      end

      specify { expect(subject.send(:start_packet_writer)).to eq(packet_writer) }
    end
  end

  describe '#init_socket' do
    let(:udp_server) do
      double 'UDPSocket', setsockopt: nil
    end

    let(:tcp_server) do
      double 'TCPServer', setsockopt: nil
    end

    context 'UDP' do
      before do
        expect(UDPSocket).to receive(:open).and_return(udp_server)
      end

      it 'returns a UDPSocket' do
        expect(udp_server).to receive(:bind).with('0.0.0.0', 1234)
        expect(subject.send(:init_socket, :UDP, 1234, '0.0.0.0')).to eq(udp_server)
      end

      it 'sets socket options to get the timestamp' do
        allow(udp_server).to receive(:bind)
        expect(subject).to receive(:socket_time_options).with(udp_server)
        subject.send(:init_socket, :UDP, 1234, '0.0.0.0')
      end
    end

    context 'TCP' do
      before do
        expect(TCPServer).to receive(:new).with('0.0.0.0', 1234).and_return(tcp_server)
      end

      it 'returns a TCPServer' do
        expect(subject.send(:init_socket, :TCP, 1234, '0.0.0.0')).to eq(tcp_server)
      end
    end

    context 'not UDP or TCP' do
      it 'raises an RTP::Error' do
        expect do
          subject.send(:init_socket, :BOBO, 1234, '1.2.3.4')
        end.to raise_error RTP::Error
      end
    end

    context 'multicast' do
      context 'multicast_address given' do
        pending
      end

      context 'multicast_address not given' do
        pending
      end
    end
  end

  describe '#multicast?' do
    context 'is not multicast' do
      specify { expect(subject).not_to be_multicast }
    end

    context 'is multicast 224.0.0.0' do
      subject { RTP::Receiver.new(ip_address: '224.0.0.0') }
      specify { expect(subject).to be_multicast }
    end

    context 'is multicast 239.255.255.255' do
      subject { RTP::Receiver.new(ip_address: '239.255.255.255') }
      specify { expect(subject).to be_multicast }
    end
  end

  describe '#start_listener' do
    let(:listener) do
      l = double 'Thread'
      allow(l).to receive(:abort_on_exception=)

      l
    end

    let(:data) { double 'socket data', size: 10 }
    let(:socket_info) { double 'socket info', timestamp: '12345' }
    let(:message) { [data, socket_info] }
    let(:socket) { double 'Socket', recvmsg_nonblock: message }

    it 'starts a new Thread and returns that' do
      expect(Thread).to receive(:start).with(socket).and_return(listener)
      expect(subject.send(:start_listener, socket)).to eq(listener)
    end

    it 'receives data from the client' do
      allow(Thread).to receive(:start).and_yield
      allow(subject).to receive(:loop).and_yield

      expect(socket).to receive(:recvmsg_nonblock).with(1500).and_return(message)

      subject.send(:start_listener, socket)

      allow(Thread).to receive(:start).and_call_original
    end

    it 'adds the socket data and timestamp to @packets' do
      allow(Thread).to receive(:start).and_yield
      allow(subject).to receive(:loop).and_yield

      expect(subject.instance_variable_get(:@packets)).to receive(:<<)
             .with [data, '12345']
      subject.send(:start_listener, socket)
    end
  end

  describe '#stop_listener' do
    let(:listener) { double '@listener' }

    before do
      subject.instance_variable_set(:@listener, listener)
    end

    context 'listening' do
      before { allow(subject).to receive(:listening?).and_return(true) }

      it 'kills the listener and resets it' do
        expect(listener).to receive(:kill)
        subject.send(:stop_listener)
        expect(subject.instance_variable_get(:@listener)).to be_nil
      end
    end

    context 'not listening' do
      before { allow(subject).to receive(:listening?).and_return(false) }

      it "listener doesn't get killed but is reset" do
        expect(listener).not_to receive(:kill)
        subject.send(:stop_listener)
        expect(subject.instance_variable_get(:@listener)).to be_nil
      end
    end
  end

  describe '#stop_packet_writer' do
    let(:packet_writer) { double '@packet_writer' }
    before { subject.instance_variable_set(:@packet_writer, packet_writer) }

    it 'closes the @capture_file' do
      allow(subject).to receive(:writing_packets?)
      expect(subject.instance_variable_get(:@capture_file)).to receive(:close)
      subject.send(:stop_packet_writer)
    end

    context 'writing packets' do
      before do
        expect(subject).to receive(:writing_packets?).and_return(true)
        expect(subject).to receive(:writing_packets?).and_return(false)
      end

      it 'kills the @packet_writer and sets it to nil' do
        expect(subject.instance_variable_get(:@packet_writer)).to receive(:kill)
        subject.send(:stop_packet_writer)
        expect(subject.instance_variable_get(:@packet_writer)).to be_nil
      end
    end

    context 'not writing packets' do
      before do
        expect(subject).to receive(:writing_packets?).and_return(false)
        expect(subject).to receive(:writing_packets?).and_return(false)
      end

      it 'sets @packet_writer it to nil' do
        expect(subject.instance_variable_get(:@packet_writer)).not_to receive(:kill)
        subject.send(:stop_packet_writer)
        expect(subject.instance_variable_get(:@packet_writer)).to be_nil
      end
    end
  end
end
