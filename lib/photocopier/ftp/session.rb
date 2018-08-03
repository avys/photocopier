module Photocopier
  class FTP
    class Session
      def initialize(options)
        @scheme = options[:scheme]

        if sftp?
          @session = Net::SFTP.start(
            options[:host],
            options[:user],
            password: options[:password],
            port: options[:port] || 22
          )
        else
          @session = Net::FTP.open(
            options[:host],
            username: options[:user],
            password: options[:password],
            port: options[:port] || 21,
            passive: options[:passive] || false
          )
        end
      end

      def get(remote, local)
        if sftp?
          @session.download!(remote, local)
        else
          @session.get(remote, local)
        end
      end

      def put_file(local, remote)
        if sftp?
          @session.upload!(local, remote)
        else
          @session.put(local, remote)
        end
      end

      def delete(remote)
        if sftp?
          @session.remove!(remote)
        else
          @session.delete(remote)
        end
      end

      private

      def sftp?
        @scheme == 'sftp'
      end
    end
  end
end
