resque-multi-step
======

Resque multi-step provides an abstraction for managing multiple step
async tasks.

Status
----

This software is not considered stable at this time.  Use at your own risk.

Using multi-step tasks
----

Consider a situation where you need to perform several actions and
would like those actions to run in parallel and you would like to keep
track of the progress.  Mutli-step can be use to implement that as
follows:

    task = Resque::Plugins::MultiStepTask.create("pirate-take-over") do |task|
      blog.posts.each do |post|                                     
        task.add_job ConvertPostToPirateTalk, post.id
      end
    end
    
A resque job will be queued for each post.  The `task` object will
keep track of how many of the tasks have been completed successfully
(`#completed_count`).  That combined with the overall job count
(`#total_job_count`) make it easy to compute the percentage completion
of a mutli-step task.

The failed job count (`#failed_count`) makes it easy to determine if
problem has occurred during the execution.

Looking up existing tasks
----

Once you have kicked off a job you can look it up again later using
it's task id.  First you persist the task id when you create the task.

    task = Resque::Plugins::MultiStepTask.create('pirate-take-over") do |task|
      ...
    end
    blog.async_task_id = task.task_id
    blog.save!

Then you can look it up using the `.find` method on `MultiStepTask`.

    # Progress reporting action; executed in a different process.
    begin
      task = Resque::Plugins::MultiStepTask.find(blog.async_task_id)
      render :text => "percent complete #{(task.completed_count.quo(task.total_job_count) * 100).round}%
      
    rescue Resque::Plugins::MultiStepTask::NoSuchMultiStepTask
      # task completed...
     
      redirect_to blog_url(blog)
    end

As of version 2.0.0, you can also get a handle on the original multi-step 
task. This is useful if you need to add another job on the fly, that needs
to happen before the finalization.

    class ConvertPostToPirateTalk
      def self.perform(post_id)
        p = Post.find(post_id)
        p.convert_to_pirate_talk
        p.save
        
        if p.has_comments?
          p.comments.each do |c|
            # #multi_step_task is a class method defined on the class
            # before invoking #perform as a convenience. you can also
            # use #multi_step_task_id to just get the resque key.
            multi_step_task.add_job ConvertCommentToPirateTalk, c.id
          end
        end
      end
    end


Finalization
----

Often when doing mutli-step tasks there are a bunch of tasks that can
all happen in parallel and then a few that can only be executed after
all the rest have completed.  Mutli-step task finalization supports
just that use case.

Using our example, say we want to commit the solr index and then
unlock the blog we are converting to pirate talk once the conversion
is complete.

    task = Resque::Plugins::MultiStepTask.create("pirate-take-over") do |task|
      blog.posts.each do |post|                                     
        task.add_job ConvertPostToPirateTalk, post.id
      end
      
      task.add_finalization_job CommitSolr
      task.add_finalization_job UnlockBlog, blog.id
    end    

This would convert all the posts to pirate talk in parallel, using as
many workers as are available.  Once all the normal jobs are completed
the finalization jobs are run serially in a single worker.
Finalization are executed in the order in which they are registered.
In our example, solr will be committed and then, after the commit is
complete, the blog will be unlocked.

Details
----

MultiStepTask creates a queue in resque for each task.  To process
multi-step jobs you will need at least one Resque worker with
`QUEUES=*`.  This combined with [resque-fairly][] provides fair
scheduling of the constituent jobs.

Having a queue per multi-step task means that is easy to determine to
what task a particular job belongs. It also provides a nice way to see
what is going on in the system at any given time.  Just got to
resque-web and look the queue list.  Use meaningful slugs for your
tasks and you get a quick birds-eye view of what is going on.

As of version 2.0.0 MultiStepTask requires ruby 1.9 or higher.

Note on Patches/Pull Requests
----
 
* Fork the project.
* Make your feature addition or bug fix.
* Add tests for it. This is important so I don't break it in a
  future version unintentionally.
* Update history to reflect the change, increment the version properly as described at <http://semver.org/>.
* Commit
* Send me a pull request. Bonus points for topic branches.

Mailing List
----

To join the list simply send an email to <mailto:resquemultistep@librelist.com>. This will subscribe you and send you information about your subscription, including unsubscribe information.

The archive can be found at <http://librelist.com/browser/resquemultistep/>.

Copyright
-----

Copyright (c) OpenLogic, Inc. See LICENSE for details.
