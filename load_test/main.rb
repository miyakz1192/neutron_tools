
net = "bf285ec8-0e33-4482-b1a9-82a7526c11c2"
count_max=1
parallel_max=70

for count in 1..count_max do 
  puts "TEST No #{count} start"
  threads = []
  for parallel in 1..parallel_max do
    t = Thread.start(parallel) do |_parallel|
      Thread.pass
      puts "neutron port-create --name port#{_parallel} #{net}"
      `neutron port-create --name port#{_parallel} #{net}`
      sleep 1
      puts "neutron port-delete port#{_parallel}"
      `neutron port-delete port#{_parallel}`
    end
    threads << t
  end 
  threads.each do |tm|
    tm.join
  end
  puts "TEST No #{count} end"
end



