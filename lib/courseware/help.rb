class Courseware
  def self.help
    IO.popen("less", "w") do |less|
      less.puts <<-EOF.gsub(/^ {6}/, '')
                             Courseware Manager

        SYNOPSIS
          courseware [-c CONFIG] [-d] <verb> [subject] [subject] ...

        DESCRIPTION
          Manage the development lifecycle of Puppet Labs courseware. This tool is not
          required for presenting the material or for contributing minor updates.

          The following verbs are recognized:

          * print
              Render course material as PDF files. This verb accepts one or more of the
              following arguments, where the default is all.

              Arguments (optional):
                 handouts: Generate handout notes
                exercises: Generate the lab exercise manual
                solutions: Generate the solution guide

          * watermark
              Render watermarked PDF files. Accepts same arguements as the `print` verb.

          * generate or update
              Build new or update certain kinds of configuration. By default, this will
              update the stylesheet.

              Arguments (optional):
                skeleton <name>: Build a new course directory named <name> and generate
                                 required metadata for a Showoff presentation.

                         config: Write current configuration to a `courseware.yaml` file.

                         styles: Generate or update the stylesheet for the current version.

                          links: Ensure that all required symlinks are in place.

                       metadata: Interactively generate or update the `showoff.json` file.

          * validate
              Validate certain things. Not yet implemented.

          * release [type]
              Orchestrate a courseware release. Not yet implemented. Defaults to `point`.

              Puppetlabs trainers are expected to deliver the most current point release
              while training partners also have the option for delivering the most current
              quarterly reviewed release.

              Release types:
                  quarterly: This is a major reviewed release. We make approximately four
                             of these releases a year, once each quarter. All courses in
                             the repository are released simultaneously. This release is
                             required to have at least two non-author reviewers.

                      point: Release early and release often. Any time significant changes
                             are ready to go, make a release. This will increment the minor
                             revision number.

                      notes: Display release notes since last release and copy to clipboard.

          * review
              Initiate and manage the quarterly review process. Run this task and make
              needed changes on the QA branch on GitHub using the Edit Slide button in the
              Showoff toolbar. Be aware that the bar for changes here is rather high. Only
              correct TINY typos and spelling or grammar mistakes or absolute blockers.
              Anything more should be filed as a ticket and resolved in a regular release
              cycle. The quarterly release should be polished, but should not have major
              changes.

          * help
              You're looking at it.
      EOF
    end
  end
end

