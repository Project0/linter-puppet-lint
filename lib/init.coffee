{CompositeDisposable} = require 'atom'

module.exports =
  config:
    puppetLintExecutablePath:
      default: 'puppet-lint'
      title: 'Puppet Lint Executable Path'
      type: 'string'
    puppetLintArguments:
      default: '--no-autoloader_layout-check'
      title: 'Puppet Lint Arguments'
      type: 'string'

  activate: ->
    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.config.observe  \
     'linter-puppet-lint.puppetLintExecutablePath',
      (executablePath) =>
        @executablePath = executablePath
    @subscriptions.add atom.config.observe \
     'linter-puppet-lint.puppetLintArguments',
      (args) =>
        @args = [ "--log-format",\
                  "'%{kind}: %{message} on line %{line} col %{column}'" ]
        @args = @args.concat args.split(' ')

  deactivate: ->
    @subscriptions.dispose()

  puppetLinter: ->
    helpers = require 'atom-linter'
    provider =
      grammarScopes: ['source.puppet']
      scope: 'file'
      lintOnFly: true
      lint: (textEditor) =>
        return helpers.tempFile textEditor.buffer.getBaseName(), textEditor.getText(), (tmpFilename) =>
          args = @args[..]
          args.push tmpFilename
          return helpers.exec(@executablePath, args, {stream: 'both'}).then (output) ->
            throw new Error output.stdout if output.stdout.match(/^puppet-lint:/g)
            throw new Error output.stderr if output.stderr.match(/ambiguous option.*?\(OptionParser::AmbiguousOption\)/)
            if output.stderr and not output.stdout
              output.stdout = ['error: ' + output.stderr.split('\n')[0] + ' on line 1 col 1']
            regex = /(warning|error): (.+?) on line (\d+) col (\d+)/g
            messages = []
            while((match = regex.exec(output.stdout)) isnt null)
              messages.push
                type: match[1]
                filePath: textEditor.getPath()
                range: helpers.rangeFromLineNumber(textEditor, match[3] - 1, match[4] - 1)
                text: match[2]
            return messages
