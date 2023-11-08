return {
    settings = {
        python = {
            analysis = {
                extraPaths = {
                    "/opt/paraview-5.10/lib/python3.9/",
                    "/opt/paraview-5.10/lib/python3.9/site-packages",
                    "/opt/paraviewopenfoam510/lib/python3.8/",
                    "/opt/paraviewopenfoam510/lib/python3.8/site-packages"
                }   
            },
            format = {enable = false},
            diagnostics = {globals = {"vim", "spec"}}
        }
    }
}
