RSpec.describe Photocopier::SSH do
  it_behaves_like 'a Photocopier adapter'

  let(:ssh) { Photocopier::SSH.new(options) }
  let(:options) { { host: 'host', user: 'user' } }
  let(:gateway_config) { { host: 'gate_host', user: 'gate_user' } }
  let(:options_with_gateway) do
    {
      host: 'host',
      user: 'user',
      gateway: gateway_config
    }
  end

  context '#session' do
    it 'retrieves an SSH session' do
      expect(Net::SSH).to receive(:start).with('host', 'user', {})
      ssh.send(:session)
    end

    context 'given a gateway ' do
      let(:options) { options_with_gateway }
      let(:gateway) { double }

      it 'goes through it to retrieve a session' do
        allow(Net::SSH::Gateway).to receive(:new)
          .with('gate_host', 'gate_user', {}).and_return(gateway)

        expect(gateway).to receive(:ssh).with('host', 'user', {})
        ssh.send(:session)
      end
    end
  end

  context '#ssh_command' do
    let(:options) { { host: 'host' } }

    it 'should build an ssh command' do
      expect(ssh.send(:ssh_command, options)).to eq('ssh host')
    end

    context 'given a port' do
      let(:options) { { host: 'host', port: 'port' } }
      it 'should be added to the command' do
        expect(ssh.send(:ssh_command, options)).to eq('ssh -p port host')
      end
    end

    context 'given a user' do
      let(:options) { { host: 'host', user: 'user' } }
      it 'should be added to the command' do
        expect(ssh.send(:ssh_command, options)).to eq('ssh user@host')
      end
    end

    context 'given a password' do
      let(:options) { { host: 'host', password: 'password' } }

      it 'sshpass should be added to the command' do
        expect(ssh.send(:ssh_command, options)).to eq('sshpass -p password ssh host')
      end
    end
  end

  context '#rsh_arguments' do
    it 'should build arguments for rsync' do
      expect(ssh).to receive(:ssh_command).with(options)
      ssh.send(:rsh_arguments)
    end

    context 'given a gateway' do
      let(:options) { options_with_gateway }

      it 'should include gateway options' do
        expect(ssh).to receive(:ssh_command).with(gateway_config)
        expect(ssh).to receive(:ssh_command).with(options)
        ssh.send(:rsh_arguments)
      end
    end
  end

  context '#rsync' do
    let(:options) do
      {
        host: 'host',
        user: 'user',
        port: 8888,
        rsync_options: '--human-readable --partial'
      }
    end

    it 'should build an rsync command' do
      command = [
        'rsync',
        '--progress',
        '-e',
        "'ssh -p 8888 user@host'",
        '-rlpt',
        '--compress',
        '--omit-dir-times',
        '--delete',
        '--human-readable',
        '--partial',
        '--include /wp-content/',
        '--include /wp-content/plugins/',
        '--exclude .git',
        '--exclude \\*.sql',
        '--exclude tmp/\\*',
        '--exclude wp-content/\\*.sql',
        '--exclude Gemfile\\*',
        '--exclude bin/',
        'source\\ path',
        'destination\\ path'
      ]
      expect(ssh).to receive(:run).with(command.join(' '))
      ssh.send(
        :rsync,
        'source path',
        'destination path',
        ['.git', '*.sql', 'tmp/*', 'wp-content/*.sql', 'Gemfile*', 'bin/'],
        ['/wp-content/', '/wp-content/plugins/']
      )
    end
  end

  context 'adapter interface' do
    let(:remote_path) { double }
    let(:file_path)   { double }
    let(:scp)         { double }
    let(:session)     { double(scp: scp) }

    before(:each) do
      allow(ssh).to receive(:session).and_return(session)
    end

    context '#get' do
      it 'should get a remote path' do
        expect(scp).to receive(:download!).with(remote_path, file_path)
        ssh.get(remote_path, file_path)
      end
    end

    context '#put_file' do
      it 'should send a file to remote' do
        expect(scp).to receive(:upload!).with(file_path, remote_path)
        ssh.put_file(file_path, remote_path)
      end
    end

    context '#delete' do
      it 'should delete a remote path' do
        expect(ssh).to receive(:exec!).with('rm -rf my\\ directory')
        ssh.delete('my directory')
      end
    end

    context 'directories management' do
      let(:exclude_list) { [] }
      let(:include_list) { [] }

      context '#get_directory' do
        it 'should get a remote directory' do
          expect(FileUtils).to receive(:mkdir_p).with('local_path')
          expect(ssh).to receive(:rsync)
            .with(':remote_path/', 'local_path', exclude_list, include_list)

          ssh.get_directory('remote_path', 'local_path', exclude_list)
        end
      end

      context '#put_directory' do
        it 'should send a directory to remote' do
          expect(ssh).to receive(:rsync)
            .with('local_path/', ':remote_path', exclude_list, include_list)

          ssh.put_directory('local_path', 'remote_path', exclude_list)
        end
      end
    end
  end
end
