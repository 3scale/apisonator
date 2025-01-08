# Copyright © 2020 Nicky Peeters
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
# documentation files (the “Software”), to deal in the Software without restriction, including without limitation the
# rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all copies or substantial portions
# of the Software.
# THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO
# THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require 'rubygems'
require 'openssl'

module TestHelpers
  module Certificates
    def create_key(alg)
      case alg
      when :rsa
        OpenSSL::PKey::RSA.new(2048)
      when :dsa
        OpenSSL::PKey::DSA.new(2048)
      when :ec
        OpenSSL::PKey::EC.generate("prime256v1")
      end
    end

    def create_ca(key = create_key(:rsa))
      root_ca = OpenSSL::X509::Certificate.new
      root_ca.version = 2 # cf. RFC 5280 - to make it a "v3" certificate
      root_ca.serial = 0x1
      root_ca.subject = OpenSSL::X509::Name.parse "/DC=test/DC=backend/CN=TestCA"
      root_ca.issuer = root_ca.subject # root CA's are "self-signed"
      root_ca.public_key = get_public_key(key)
      root_ca.not_before = Time.now
      root_ca.not_after = root_ca.not_before + 2 * 365 * 24 * 60 * 60 # 2 years validity

      ef = OpenSSL::X509::ExtensionFactory.new
      ef.subject_certificate = root_ca
      ef.issuer_certificate = root_ca

      root_ca.add_extension(ef.create_extension("basicConstraints","CA:TRUE", true))
      root_ca.add_extension(ef.create_extension("keyUsage","keyCertSign, cRLSign", true))
      root_ca.add_extension(ef.create_extension("subjectKeyIdentifier","hash", false))
      root_ca.add_extension(ef.create_extension("authorityKeyIdentifier","keyid:always", false))

      root_ca.sign(key, OpenSSL::Digest.new('SHA512'))

      root_ca
    end

    def create_cert(key = create_key(:rsa), root_ca, root_key)
      cert = OpenSSL::X509::Certificate.new
      cert.version = 2
      cert.serial = 0x2
      cert.subject = OpenSSL::X509::Name.parse "/DC=test/DC=backend/CN=TestCert"
      cert.issuer = root_ca.subject # root CA is the issuer
      cert.public_key = get_public_key(key)
      cert.not_before = Time.now
      cert.not_after = cert.not_before + 1 * 365 * 24 * 60 * 60 # 1 year validity

      ef = OpenSSL::X509::ExtensionFactory.new
      ef.subject_certificate = cert
      ef.issuer_certificate = root_ca

      cert.add_extension(ef.create_extension("keyUsage","digitalSignature", true))
      cert.add_extension(ef.create_extension("subjectKeyIdentifier","hash", false))
      cert.sign(root_key, OpenSSL::Digest.new('SHA256'))

      cert
    end

    private

    def get_public_key(key)
      return OpenSSL::PKey::EC.new key if key.is_a? OpenSSL::PKey::EC

      key.public_key
    end
  end
end
