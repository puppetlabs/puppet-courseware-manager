class Courseware
  def self.help
    IO.popen("less", "w") do |less|
      less.puts <<-EOF.gsub(/^ {6}/, '')
                             Courseware Manager

        SYNOPSIS
          courseware [-c CONFIG] [-d] <verb> [subject] [subject] ...

        DESCRIPTION
          Manage the development lifecycle of Puppet courseware. This tool is not
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
              Runs validation checks on the presentation. Defaults to running all the checks.

              Validators:
                  obsolete: Lists all unreferenced images and slides. This reference checks
                            all slides and all CSS stylesheets. Case sensitive.

                   missing: Lists all slides that are missing. Note that this does not check
                            for missing image files yet. Case sensitive.

                      lint: Runs a markdown linter on each slide file, using our own style
                            definition.

          * release [type]
              Orchestrate a courseware release. Defaults to `point`.

              All instructors are expected to deliver the most current point release, except
              in extraordinary cases. We follow Semver, as closely as it can be adapted to
              classroom usage. Instructors can trust that updates with high potential to cause
              classroom disruptions will never make it into a point release.

                                       http://semver.org

              Release types:
                      major: This is a major release with "breaking" changes, such as a major
                             product update, or significant classroom workflow changes. This
                             is not necessarily tied to product releases. Instructors should
                             expect to spend significant time studying the new material thoroughly.

                      minor: This indicates a significant change in content. Instructors
                             should take extra time to review updates in minor releases.
                             The release cadence is roughly once a quarter, give or take.

                      point: Release early and release often. Changes made in the regular
                             maintenance cycle will typically fit into this category.

                      notes: Display release notes since last release and copy to clipboard.

          * help
              You're looking at it.
      EOF
    end
  end
end

