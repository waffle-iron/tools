#!/usr/bin/ruby

require 'thinreports'
require 'rqrcode'
require 'rqrcode_png'
require 'chunky_png'

require 'digest/sha1'
require 'fileutils'

require 'sinatra/base'

class FormMaker < Sinatra::Base

  # Thinreports レイアウトファイル
  APPLICATION_FORM_PATH = 'data/appform'

  def get_hash(vars)
    Digest::SHA1.hexdigest(vars.to_s)
  end

  def make_pdf(vars)
    pdfpath = get_hash(vars) + ".pdf"
    return pdfpath if File.exist?(pdfpath)
    # Make QR image
    qrimg_file = get_hash(vars) + '-qr.png'
    qr = RQRCode::QRCode.new(vars[:qrtext], size: 3, level: :h)
    png = qr.to_img
    png.resize 200, 200
    png.save qrimg_file

    report = Thinreports::Report.new(layout: APPLICATION_FORM_PATH)
    report.start_new_page do
      %i(date name address email).each do |k|
        item(k).value = vars[k]
      end
      item(:qrimage).src = qrimg_file
    end

    report.generate filename: pdfpath 
    FileUtils.rm qrimg_file
    pdfpath
  end

  def today
    t = Time.now
    Time.local(t.year, t.month, t.day)
  end

  def genform(params)

    vars = {
        date: today,
        name: params[:name],
        address: params[:address],
        email: params[:email],
        qrtext: params[:email],
    }

    pdffile = make_pdf(vars)

    send_file pdffile
  end

  get "/" do
    erb :index
  end


  get "/form" do
    genform params
  end

  post "/form" do
    genform params
  end

end

# vim:set ts=2 sw=2 et:
