using Images
using ImageTransformations
using Random
using ProgressMeter

function render_fractal()
    # --- Base Parameters ---
    width       = 20000
    height      = width
    num_points  = 100_000_000
    iterations  = 10
    span        = 50.0
    k           = 0.80

    # --- Supersampling Setup ---
    img_scaling = 1.5
    resx        = round(Int, width * img_scaling)
    resy        = round(Int, height * img_scaling)

    # --- Chunking Setup ---
    batch_size  = 100_000
    num_batches = num_points ÷ batch_size

    # --- Precomputations ---
    lnk       = log(k)
    atanlnk   = atan(lnk)
    downscale = 3.0 / k
    lnkplusi  = complex(lnk, 1.0)
    
    wby2 = resx / 2.0
    hby2 = resy / 2.0
    
    tvr1 = span * lnkplusi
    tvr2 = lnkplusi / downscale
    
    phase_shift = exp(-im * atanlnk) / downscale

    disp = zeros(Bool, resx, resy)

    println("Initializing render on $(Threads.nthreads()) threads...")
    println("Internal rendering resolution: $(resx)x$(resy)")

    @showprogress Threads.@threads for _ in 1:num_batches
        
        rng = Random.default_rng()
        
        for _ in 1:batch_size
            r_sign = rand(rng) > 0.5 ? 1.0 : -1.0
            z = 2.0 * round((2.0 * rand(rng) - 1.0) * span * rand(rng)) + 
                (1.0 - exp(tvr1 * rand(rng) * rand(rng))) * r_sign

            for _ in 1:iterations
                rz     = real(z)
                iz     = imag(z)
                rz_abs = abs(rz)
                sgn    = rz > 0 ? 1.0 : -1.0
                
                E = exp(tvr2 * rz_abs)
                
                term1 = 2.0 * round((2.0 * rand(rng) - 1.0) * span * rand(rng))
                term2 = sgn * (1.0 - E)
                term3 = iz * E * phase_shift
                
                z = term1 + term2 + term3
            end
            
            rz     = real(z)
            iz     = imag(z)
            rz_abs = abs(rz)
            sgn    = rz > 0 ? 1.0 : -1.0
            
            E     = exp(tvr2 * rz_abs)
            term2 = sgn * (1.0 - E)
            term3 = iz * E * phase_shift
            
            z = term2 + term3
            
            x_idx = round(Int, (imag(z) / 2.0 + 1.0) * wby2)
            y_idx = round(Int, (real(z) / 2.0 + 1.0) * hby2)
            
            if 1 <= x_idx <= resx && 1 <= y_idx <= resy
                @inbounds disp[x_idx, y_idx] = true
            end
        end
    end

    println("Applying anti-aliasing (downscaling to $(width)x$(height))...")
    smooth_img = imresize(colorview(Gray, disp), (width, height))

    println("Saving image...")
    save("output.png", smooth_img)
    println("Done!")
end

@time render_fractal()
