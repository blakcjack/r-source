#  File src/library/parallel/R/worker.R
#  Part of the R package, https://www.R-project.org
#
#  Copyright (C) 1995-2020 The R Core Team
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  A copy of the GNU General Public License is available at
#  https://www.R-project.org/Licenses/

## Derived from snow 0.3-6 by Luke Tierney

slaveCommand <- function(master)
{
    tryCatch({
        msg <- recvData(master)
        # cat(paste("Type:", msg$type, "\n"))

        if (msg$type == "DONE") {
            closeNode(master)
            FALSE
        } else if (msg$type == "EXEC") {
            success <- TRUE
            ## This uses the message rather than the exception since
            ## the exception class/methods may not be available on the
            ## master.
            handler <- function(e) {
                success <<- FALSE
                structure(conditionMessage(e),
                          class = c("snow-try-error","try-error"))
            }
            t1 <- proc.time()
            value <- tryCatch(do.call(msg$data$fun, msg$data$args, quote = TRUE),
                              error = handler)
            t2 <- proc.time()
            value <- list(type = "VALUE", value = value, success = success,
                          time = t2 - t1, tag = msg$data$tag)
            msg <- NULL ## release for GC
            sendData(master, value)
            value <- NULL ## release for GC
            TRUE
        } else {
            ## unknown command / shutdown
            TRUE
        }
    }, interrupt = function(e) TRUE)
}

slaveLoop <- function(master)
{
    if (!is.null(master))
        while(slaveCommand(master)) {}
}

## NB: this only sinks the connections, not C-level stdout/err.
sinkWorkerOutput <- function(outfile)
{
    if (nzchar(outfile)) {
        if (.Platform$OS.type == "windows" && outfile == "/dev/null")
            outfile <- "nul:"
        ## all the workers log to the same file.
        outcon <- file(outfile, open = "a")
        sink(outcon)
        sink(outcon, type = "message")
    }
}

