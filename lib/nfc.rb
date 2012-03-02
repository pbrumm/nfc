require 'singleton'
require 'thread'
require 'nfc/nfc'
require 'nfc/device'
require 'nfc/iso14443a'
require 'nfc/felica'

###
# NFC is a class for dealing with Near Field Communication systems.  This
# library will read RFID tags from an RFID reader.  You should start by reading
# NFC#find
class NFC
  VERSION = '2.1.0'

  include Singleton

  ###
  # Create a new NFC class.  This is private, do this instead:
  #   NFC.instance
  def initialize
    @device = nil
    @mutex = Mutex.new
  end
  def toggle_led(options)
    state = calc_led_changes(options)
    resp = device.led(*state)
    calc_led_state(resp)
  end

  def led_state
    resp = device.led(0,0,0,0)
    calc_led_state(resp)

  end
  ###
  # Deactivate the detection field
  def deactivate_field
    device.configure Device::DCO_ACTIVATE_FIELD, 0
  end

  ###
  # Activate the detection field
  def activate_field
    device.configure Device::DCO_ACTIVATE_FIELD, 1
  end

  ###
  # Do CRC checks
  def crc= value
    device.configure Device::DCO_HANDLE_CRC, value ? 1 : 0
  end

  ###
  # Parity checks
  def parity= v
    device.configure Device::DCO_HANDLE_PARITY, v ? 1 : 0
  end

  ###
  # Get the device
  def device
    @device ||= NFC::Device.connect
  end

  ###
  # Block until a passive tag is detected
  def infinite_list_passive= v
    device.configure Device::DCO_INFINITE_LIST_PASSIVE, v ? 1 : 0
  end

  ###
  # Select a tag
  def select
    device.select Device::IM_ISO14443A_106
  end
  alias :detect :select

  ###
  # Deselect a tag
  def deselect
    device.deselect
  end

  # Read your tag and print the info.
  #
  #   p NFC.instance.find
  #
  # NFC#find will return immidiately, which means you should have a tag
  # sitting on the reader when running it.  If you'd like it to block until
  # it detects a tag, give find a block like so:
  #
  #   NFC.instance.find do |tag|
  #     p tag
  #   end
  #
  # You can even run in an infinite loop if you'd like to continually find
  # tags:
  #
  #   loop do
  #     NFC.instance.find do |tag|
  #       p tag
  #     end
  #   end
  def find
    loop do 
      @mutex.lock
      begin
        deactivate_field
        self.infinite_list_passive = block_given?
        self.crc = true
        self.parity = true
        activate_field
        tag = detect
        deselect
      ensure
        @mutex.unlock
      end
      if block_given?
        resp = yield tag
        if resp == false
          return tag
        end
      else
        return tag
      end
    end
  ensure 
    @mutex.lock
    deactivate_field
    self.infinite_list_passive = false
    deselect
    @mutex.unlock 
  end


  def calc_led_changes(options)
    return [0,0,0,0] if options.nil?
    options[:blink_on_dur] ||= 0
    options[:blink_off_dur] ||= options[:blink_on_dur]
    options[:repeat] ||= options[:blink_on_dur] > 0 ? 1 : 0
    options[:current_color] ||= led_state
    options[:blink_color] ||= nil
    options[:init_blink_color] ||= nil
    options[:final_color] ||= options[:current_color]
    
    p2_led_state = 0
    t1_blink_dur = (options[:blink_on_dur] * 1000 / 10).to_i   # convert to miliseconds
    t2_blink_dur = (options[:blink_off_dur] * 1000 / 10).to_i
    b2_reps = options[:repeat].to_i

    case options[:final_color]
    when nil
      p2_led_state |= 0b00001100
    when :red
      p2_led_state |= 0b00001101
    when :green
      p2_led_state |= 0b00001110
    when :orange
      p2_led_state |= 0b00001111
    end

    case options[:init_blink_color]
    when nil
      p2_led_state |= 0b00000000
    when :red
      p2_led_state |= 0b00010000
    when :green
      p2_led_state |= 0b00100000
    when :orange
      p2_led_state |= 0b00110000
    end
    case options[:blink_color]
    when nil
      p2_led_state |= 0b00000000
    when :red
      p2_led_state |= 0b01000000
    when :green
      p2_led_state |= 0b10000000
    when :orange
      p2_led_state |= 0b11000000
    end



    [p2_led_state, t1_blink_dur, t2_blink_dur, b2_reps]
  end
  def calc_led_state(num)
    color = case num
            when 1
              :green
            when 2
              :red
            when 3
              :orange
            when 0
              nil
            end
    color
  end
end
