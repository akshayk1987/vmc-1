module VMC
  module BetterHelp
    @@groups = []
    @@tree = {}

    def nothing_printable?(group, all = false)
      group[:members].reject { |_, _, opts| !all && opts[:hidden] }.empty? &&
        group[:children].all? { |g| nothing_printable?(g) }
    end

    def print_help_group(group, all = false, indent = 0)
      return if nothing_printable?(group, all)

      members = group[:members]

      unless all
        members = members.reject do |_, _, opts|
          opts[:hidden]
        end
      end

      members = members.collect do |cls, name, opts|
        [cls, cls.tasks[name]]
      end

      i = "  " * indent

      print i
      puts group[:description]

      width = 0
      members.each do |cls, t|
        sub = find_subcommand_name(cls)
        len = (sub ? sub.size + 1 : 0) + t.usage.size
        if len > width
          width = len
        end
      end

      members.each do |cls, t|
        sub = find_subcommand_name(cls)

        print "#{i}  "

        label = sub ? "#{sub} " : ""
        label << t.usage

        print "#{label.ljust(width)}\t#{t.description}"

        puts ""
      end

      puts "" unless members.empty?

      group[:children].each do |group|
        print_help_group(group, all, indent + 1)
      end
    end

    def groups(*tree)
      tree.each do |*args|
        add_group(@@groups, @@tree, *args.first)
      end
    end

    def add_group(groups, tree, name, desc, *subs)
      members = []

      meta = {:members => members, :children => []}
      groups << meta

      tree[name] = {:members => members, :children => {}}

      meta[:description] = desc

      subs.each do |*args|
        add_group(meta[:children], tree[name][:children], *args.first)
      end
    end

    def group(*names)
      options =
        if names.last.is_a? Hash
          names.pop
        else
          {}
        end

      where = @@tree
      top = true
      names.each do |n|
        where = where[:children] unless top

        unless where
          raise "unknown group: #{names.join("/")}"
        end

        where = where[n]

        top = false
      end

      where[:members] << [self, @usage.split.first, options]
    end

    def subcommand_classes
      @subcommand_classes ||= {}
    end

    def subcommand_names
      @subcommand_names ||= {}
    end

    def subcommand(name, cls)
      subcommand_classes[name] = cls
      subcommand_names[cls] = name
      super
    end

    def find_subcommand_name(cls)
      found = subcommand_names[cls]
      return found if found

      if superclass.respond_to?(:find_subcommand_name) &&
          found = superclass.find_subcommand_name(cls)
        return found
      end

      subcommand_classes.each do |name, sub|
        if found = sub.find_subcommand_name(cls)
          return name + " " + found
        end
      end

      nil
    end

    def find_subcommand(name)
      found = subcommand_classes[name]
      return found if found

      if superclass.respond_to? :find_subcommand
        superclass.find_subcommand(name)
      else
        nil
      end
    end

    def task_help(shell, task_name)
      if sub = find_subcommand(task_name)
        sub.help(shell, true)
      elsif t = all_tasks[task_name]
        puts t.description
        puts ""
        puts "Usage: #{t.usage}"
        puts ""
        class_options_help(shell, nil => t.options.map { |_, o| o })
      else
        super
      end
    end

    def help(shell, subcommand = false)
      puts "Tasks:"

      width = 0
      @tasks.each do |_, t|
        len = t.usage.size
        if len > width
          width = len
        end
      end

      @tasks.each do |_, t|
        print "  "

        print "#{t.usage.ljust(width)}\t#{t.description}"

        puts ""
      end

      puts ""

      class_options_help(shell)
    end

    def print_help_groups(all = false)
      @@groups.each do |commands|
        print_help_group(commands, all)
      end
    end
  end
end